---
title: CircleCI
description: Install Lando on CircleCI
---

# CircleCI

The CircleCI Actions quickstart is:

```yaml
jobs:
  my-workflow:
    machine:
      image: ubuntu-2204:current
    steps:
      - checkout
      - run:
          name: Install Lando
          command: /bin/bash -c "$(curl -fsSL https://get.lando.dev/setup-lando.sh)"
```

For more examples you can check out [our tests](https://github.com/lando/setup-lando/blob/main/.circleci/config.yml).
