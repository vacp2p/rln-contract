# Hardhat Project for Rln-interep-contract

## Compilation

```shell
yarn compile
```

## Testing
```shell
yarn test
```

## Deploying

- To deploy on local node, first start the local node and then run the deploy script

```shell
yarn start
yarn deploy:localhost
```

- To deploy to an target network (like Goerli), use the name as mentioned in the Hardhat config file.

```shell
yarn deploy:goerli
```
## References

For more information, see https://hardhat.org/hardhat-runner/docs/guides/project-setup