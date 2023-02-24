#!/usr/bin/env bash
# npm install --save-dev prettier prettier-plugin-solidity
npx prettier --write 'src/**/*.sol'

npx prettier --write 'script/**/*.sol'

npx prettier --write 'test/**/*.sol'