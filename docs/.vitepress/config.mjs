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
    ['link', {rel: 'icon', href: '/core/favicon.ico', size: 'any'}],
    ['link', {rel: 'icon', href: '/core/favicon.svg', type: 'image/svg+xml'}],
  ],
  themeConfig: {
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
          collapsed: false,
          items: [
            {text: 'GitHub', link: 'https://github.com/lando/dotnet/issues/new/choose'},
            {text: 'Slack', link: 'https://www.launchpass.com/devwithlando'},
            {text: 'Contact Us', link: 'https://docs.lando.dev/support'},
            {text: 'Troubleshooting', link: 'https://docs.lando.dev/troubleshooting'},
          ],
        },
        {
          text: 'Contributing',
          collapsed: true,
          items: [
            {text: 'Getting Involved', link: 'https://docs.lando.dev/contrib/index'},
            {text: 'Coding', link: 'https://docs.lando.dev/contrib/coder'},
            {text: 'Evangelizing', link: 'https://docs.lando.dev/contrib/evangelist'},
            {text: 'Sponsoring', link: 'https://docs.lando.dev/contrib/sponsoring'},
            {text: 'Security', link: 'https://docs.lando.dev/security'},
            {text: 'Team', link: 'https://docs.lando.dev/team'},
          ],
        },
        {
          collapsed: false,
          items: [
            {
              text: 'Lando 101',
              link: 'https://docs.lando.dev/lando-101',
            },
            {
              text: 'Guides',
              link: 'https://docs.lando.dev/guides',
            },
            {
              text: 'Examples',
              link: 'https://github.com/lando/core/tree/main/examples',
            },
          ],
        },
        {
          collapsed: false,
          items: [
            {
              text: 'Plugins',
              link: 'https://docs.lando.dev/plugins',
            },
          ],
        },

      ],
    },
  },
});
