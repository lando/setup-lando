import {createRequire} from 'module';
import {HttpClient} from '@actions/http-client';

import {defineConfig} from '@lando/vitepress-theme-default-plus/config';

const channel = 'stable';
const http = new HttpClient();
const require = createRequire(import.meta.url);
const url = `https://raw.githubusercontent.com/lando/core/refs/heads/main/release-aliases/3-${channel.toUpperCase()}`;

// plugin info
const {name, version} = require('../../package.json');
const landoPlugin = name.replace('@lando/', '');
let v = `v${version}`;

// attempt to update version information from alias
try {
  const response = await http.get(url);
  const body = await response.readBody();
  v = body.trim();
} catch (error) {
  console.error(error);
}

const sidebarEnder = {
  text: v,
  collapsed: true,
  items: [
    {
      text: 'Other Doc Versions',
      items: [
        {rel: 'mvb', text: 'stable', target: '_blank', link: '/v/stable/'},
        {rel: 'mvb', text: 'edge', target: '_blank', link: '/v/edge'},
        {rel: 'mvb', text: '<strong>see all versions</strong>', target: '_self', link: '/v/'},
      ],
    },
    {text: 'Other Releases', link: 'https://github.com/lando/setup-lando/releases'},
  ],
};

export default defineConfig({
  title: 'Lando 3',
  description: 'The offical Lando installation guide.',
  landoDocs: 3,
  landoPlugin,
  version,
  base: '/install/',
  head: [
    ['meta', {name: 'viewport', content: 'width=device-width, initial-scale=1'}],
    ['link', {rel: 'icon', href: '/favicon.ico', size: 'any'}],
    ['link', {rel: 'icon', href: '/favicon.svg', type: 'image/svg+xml'}],
  ],
  themeConfig: {
    multiVersionBuild: {
      build: channel,
      satisfies: '>=3.0.0',
    },
    sidebarEnder,
    sidebar: {
      '/': [
        {
          text: 'Introduction',
          collapsed: false,
          items: [
            {text: 'What it do?', link: 'https://docs.lando.dev/getting-started/'},
            {text: 'How does it work?', link: 'https://docs.lando.dev/getting-started/what-it-do'},
            {text: 'Starting your first app', link: 'https://docs.lando.dev/getting-started/first-app'},
            {text: 'Requirements', link: 'https://docs.lando.dev/getting-started/requirements'},
            {text: 'Lando 101', link: 'https://docs.lando.dev/lando-101'},
          ],
        },
        {
          text: 'Installation',
          collapsed: false,
          items: [
            {text: 'macOS', link: '/macos'},
            {text: 'Linux', link: '/linux'},
            {text: 'Windows', link: '/windows'},
            {text: 'GitHub Actions', link: '/gha'},
            {text: 'Source', link: '/source'},
          ],
        },
        {
          text: 'Help & Support',
          collapsed: true,
          items: [
            {text: 'GitHub', link: 'https://github.com/lando/dotnet/issues/new/choose'},
            {text: 'Slack', link: 'https://www.launchpass.com/devwithlando'},
            {text: 'Contact Us', link: 'https://docs.lando.dev/support'},
          ],
        },
        {
          text: 'Contributing',
          collapsed: true,
          items: [
            {text: 'Getting Involved', link: 'https://docs.lando.dev/contrib/index'},
            {text: 'Coding', link: 'https://docs.lando.dev/contrib/coder'},
            {text: 'Development', link: 'https://docs.lando.dev/contrib/development'},
            {text: 'Evangelizing', link: 'https://docs.lando.dev/contrib/evangelist'},
            {text: 'Sponsoring', link: 'https://docs.lando.dev/contrib/sponsoring'},
            {text: 'Security', link: 'https://docs.lando.dev/security'},
            {text: 'Team', link: 'https://docs.lando.dev/team'},
          ],
        },
        {
          collapsed: false,
          items: [
            {text: 'Guides', link: 'https://docs.lando.dev/guides'},
            {text: 'Troubleshooting', link: 'https://docs.lando.dev/troubleshooting'},
            {text: 'Examples', link: 'https://github.com/lando/core/tree/main/examples'},
          ],
        },
      ],
    },
  },
});
