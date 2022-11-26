The [RLN](contracts/Rln.sol) and [PoseidonHasher](contracts/PoseidonHasher.sol) smart contracts are initially borrowed from the following repository https://github.com/kilic/rlnapp and some modifications are made on top of them.
They may undertake further changes in the future as needed.

# Hardhat Project for Rln-membership-contract

## Compilation

```shell
npx hardhat compile
```

## Testing
```shell
npx hardhat test
```

## Deploying

- To deploy on local node, first start the local node and then run the deploy script

```shell
npx hardhat node
npx hardhat run --network localhost scripts/deploy.ts
```

- To deploy to an target network (like Goerli), use the name as mentioned in the Hardhat config file.

```shell
npx hardhat run --network <your-network> scripts/deploy.js
```
## References

For more information, see https://hardhat.org/hardhat-runner/docs/guides/project-setup