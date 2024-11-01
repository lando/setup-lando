import {createRequire} from 'module';

import {defineConfig} from '@lando/vitepress-theme-default-plus/config';

const require = createRequire(import.meta.url);

const {name, version} = require('../../package.json');
const landoPlugin = name.replace('@lando/', '');

export default defineConfig({
  title: 'Lando',
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
    sidebar: {
      '/': [
        {
          text: 'Introduction',
          collapsed: false,
          items: [
            {text: 'What it do?', link: '/getting-started/'},
            {text: 'How does it work?', link: '/getting-started/what-it-do'},
            {text: 'Starting your first app', link: '/getting-started/first-app'},
            {text: 'Requirements', link: '/getting-started/requirements'},
            {text: 'Lando 101', link: '/lando-101'},
          ],
        },
        {
          text: 'Installation',
          collapsed: false,
          items: [
            {text: 'macOS', link: 'https://docs.lando.dev/install/macos.html'},
            {text: 'Linux', link: 'https://docs.lando.dev/install/linux.html'},
            {text: 'Windows', link: 'https://docs.lando.dev/install/windows.html'},
            {text: 'GitHub Actions', link: 'https://docs.lando.dev/install/gha.html'},
            {text: 'Source', link: 'https://docs.lando.dev/install/source.html'},
          ],
        },
        {
          text: 'Help & Support',
          collapsed: true,
          items: [
            {text: 'GitHub', link: 'https://github.com/lando/dotnet/issues/new/choose'},
            {text: 'Slack', link: 'https://www.launchpass.com/devwithlando'},
            {text: 'Contact Us', link: '/support'},
          ],
        },
        {
          text: 'Contributing',
          collapsed: true,
          items: [
            {text: 'Getting Involved', link: '/contrib/index'},
            {text: 'Coding', link: '/contrib/coder'},
            {text: 'Development', link: '/contrib/development'},
            {text: 'Evangelizing', link: '/contrib/evangelist'},
            {text: 'Sponsoring', link: '/contrib/sponsoring'},
            {text: 'Security', link: '/security'},
            {text: 'Team', link: '/team'},
          ],
        },
        {
          collapsed: false,
          items: [
            {text: 'Guides', link: '/guides'},
            {text: 'Troubleshooting', link: '/troubleshooting'},
            {text: 'Examples', link: 'https://github.com/lando/core/tree/main/examples'},
          ],
        },
      ],
    },
  },
});
