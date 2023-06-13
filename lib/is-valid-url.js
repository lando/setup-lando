'use strict';

module.exports = url => {
  try {
    new URL(url);
    return true;
  } catch {
    return false;
  }
};
