#define WIN32_LEAN_AND_MEAN  // Exclude rarely-used stuff from Windows headers
#define NOMINMAX            // Disable min/max macros from windows.h
#include <windows.h>        // This includes winuser.h and necessary Windows definitions
#include <string>
#include <cstdio>
#include <memory>

// Define the resource ID to match the RC file
#define SCRIPT_RESOURCE 101

/**
 * Extracts command line arguments after the executable name.
 * 
 * Handles both quoted and unquoted executable names.
 * 
 * @returns {std::wstring} Arguments after the executable name.
 */
std::wstring extractCommandLineArgs() {
  std::wstring fullCommandLine = GetCommandLineW();
  size_t argsStartPos = 0;

  if (fullCommandLine[0] == L'"') {
    // Find closing quote for quoted executable name
    argsStartPos = fullCommandLine.find(L'"', 1);
    if (argsStartPos != std::wstring::npos) {
      argsStartPos++; // Move past the closing quote
    }
  } else {
    // Find first whitespace for unquoted executable name
    argsStartPos = fullCommandLine.find_first_of(L" \t");
  }

  // Return empty string if no arguments found
  if (argsStartPos == std::wstring::npos || argsStartPos >= fullCommandLine.length()) {
    return std::wstring();
  }

  // Trim leading whitespace
  argsStartPos = fullCommandLine.find_first_not_of(L" \t", argsStartPos);
  if (argsStartPos == std::wstring::npos) {
    return std::wstring();
  }

  return fullCommandLine.substr(argsStartPos);
}

/**
 * Extracts embedded PowerShell script and saves to a temporary file.
 * 
 * @param {std::wstring&} scriptPath Output parameter for the temporary script file path.
 * @returns {bool} True if script was successfully extracted and saved, false otherwise.
 */
bool extractScriptToTempFile(std::wstring& scriptPath) {
  HMODULE hModule = GetModuleHandleW(NULL);
  if (!hModule) return false;

  // Load the script resource using the numeric ID and proper type
  LPCWSTR resourceType = MAKEINTRESOURCEW(RT_RCDATA);
  HRSRC scriptResource = FindResourceW(hModule, MAKEINTRESOURCEW(SCRIPT_RESOURCE), resourceType);
  if (!scriptResource) return false;
  
  HGLOBAL loadedResource = LoadResource(hModule, scriptResource);
  if (!loadedResource) return false;
  
  LPVOID scriptData = LockResource(loadedResource);
  if (!scriptData) return false;

  DWORD scriptSize = SizeofResource(hModule, scriptResource);
  if (scriptSize == 0) return false;
  
  // Create temporary file with .ps1 extension
  wchar_t tempDirPath[MAX_PATH];
  GetTempPathW(MAX_PATH, tempDirPath);
  wchar_t tempFilePath[MAX_PATH];
  GetTempFileNameW(tempDirPath, L"ldo_", 0, tempFilePath);
  
  // Rename .tmp to .ps1
  std::wstring ps1Path = tempFilePath;
  ps1Path = ps1Path.substr(0, ps1Path.length() - 4) + L".ps1";
  if (!MoveFileW(tempFilePath, ps1Path.c_str())) {
    DeleteFileW(tempFilePath);
    return false;
  }
  scriptPath = ps1Path;
  
  // Write script to temp file
  FILE* tempFile;
  if (_wfopen_s(&tempFile, scriptPath.c_str(), L"wb") != 0) return false;

  std::unique_ptr<FILE, decltype(&fclose)> fileGuard(tempFile, fclose);
  return fwrite(scriptData, 1, scriptSize, tempFile) == scriptSize;
}

/**
 * Entry point for Windows applications.
 *
 * Workflow:
 * 1. Extract embedded PowerShell script to a temporary file
 * 2. Execute the script with PowerShell, passing through any command line arguments
 * 3. Clean up temporary files
 * 4. Return the PowerShell script's exit code
 *
 * @returns {int} PowerShell script exit code, or error code if process launch fails
 */
int WINAPI WinMain(
  HINSTANCE hInstance,
  HINSTANCE hPrevInstance,
  LPSTR lpCmdLine,
  int nCmdShow)
{
  std::wstring tempScriptPath;
  if (!extractScriptToTempFile(tempScriptPath)) {
    return GetLastError();
  }

  // Use RAII to ensure temp file cleanup
  struct TempFileGuard {
    const std::wstring& path;
    ~TempFileGuard() { DeleteFileW(path.c_str()); }
  } tempFileGuard{tempScriptPath};

  // Construct PowerShell command
  std::wstring args = extractCommandLineArgs();
  std::wstring powershellCommand = L"\"C:\\Windows\\system32\\WindowsPowerShell\\v1.0\\powershell.exe\" "
                                   L"-ExecutionPolicy Bypass "
                                   L"-NoProfile "
                                   L"-Command \"& { "
                                   L"$ErrorActionPreference = 'Stop'; "
                                   L"& '" + tempScriptPath + L"' " + args + L"; "
                                   L"exit $LASTEXITCODE"
                                   L"}\"";

  STARTUPINFOW startupInfo = {};
  startupInfo.cb = sizeof(startupInfo);
  PROCESS_INFORMATION processInfo = {};

  BOOL processCreated = CreateProcessW(
    NULL,
    &powershellCommand[0],
    NULL,
    NULL,
    TRUE,
    0,  // No special creation flags
    NULL,
    NULL,
    &startupInfo,
    &processInfo
  );
    
  if (!processCreated) {
    return GetLastError();
  }

  // Use RAII for process handles
  std::unique_ptr<void, decltype(&CloseHandle)> processGuard(processInfo.hProcess, CloseHandle);
  std::unique_ptr<void, decltype(&CloseHandle)> threadGuard(processInfo.hThread, CloseHandle);

  WaitForSingleObject(processInfo.hProcess, INFINITE);

  DWORD exitCode = 0;
  if (!GetExitCodeProcess(processInfo.hProcess, &exitCode)) {
    return GetLastError();
  }
    
  return exitCode;
}
