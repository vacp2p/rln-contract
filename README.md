# rln-contract [![Github Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry] [![License: MIT][license-badge]][license]

[gha]: https://github.com/vacp2p/foundry-template/actions
[gha-badge]: https://github.com/vacp2p/foundry-template/actions/workflows/ci.yml/badge.svg
[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license]: https://opensource.org/licenses/MIT
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg

A Foundry-based project for Rate Limiting Nullifiers.


## Getting Started

```sh
pnpm install # install Solhint, Prettier, and other Node.js deps
forge install # install Foundry's dependencies
```

If this is your first time with Foundry, check out the
[installation](https://github.com/foundry-rs/foundry#installation) instructions.


## Usage 

### Compilation

```sh
forge build

### Format

```sh
forge fmt
```

### Clean

Deletes the build artifacts and cache directories:

```sh
forge clean
```

### Gas Usage

Get a gas report:

```sh
forge test --gas-report
```

### Test

Run the tests:

```sh
forge test
```


### Deployment

Ensure you setup the .env file with the correct values mentioned in the .env.example file.

```sh
./script/deploy.sh rln
```

This will deploy the RLN contract, with its associated libraries to the specified network.
If forge supports the network, it will also verify the contract on the block explorer.

## License

This project is dual licensed under MIT and APACHE-2.0.
