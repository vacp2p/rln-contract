# Hardhat Project for Rln-interep-contract

## Compilation

```shell
yarn compile
```

## Testing

```shell
yarn test
```

## Test with Waku-RLN-Relay (chat2)

1. Clone [nwaku](https://github.com/waku-org/nwaku) and switch to the `rln-interep-poc` branch

2. Fetch dependencies

   ```shell
   yarn
   ```

3. In a different terminal window, start the local eth node

   ```shell
   yarn start
   ```

4. In a new terminal window, run the deployment script and the interep group registration script

   ```shell
   yarn deploy localhost_integration --reset && yarn e2e 11d5888ff45486b90a506367a4262e65a097c4b8eb509f3db01fbff714a96cbb
   ```

   The string after `yarn e2e` is used for deterministic credential generation.

   Make note of the ID Commitment, ID Key and Index from the output of running the `e2e` script.

5. Open 3 terminal windows with `nwaku` as the base directory

6. In one of them, build `chat2`

   ```shell
   make -j8 chat2 RLN=true
   ```

7. Run Alice's chat2 instance

   ```shell
    ./build/chat2 --fleet:none --content-topic:/toy-chat/2/luzhou/proto --rln-relay:true --rln-relay-dynamic:true --rln-relay-eth-contract-address:<use-the-contract-from-step-4> --rln-relay-eth-client-address:ws://localhost:8545 --ports-shift:5 --rln-relay-eth-account-private-key:3c914dff62bd200e1e1b1af9d40eace4bc70875d1007b8cad4a950d3c7b3e442 --log-level=DEBUG
   # Choose a nickname >> Alice
   ```

   Make note of Alice's peer address

8. In a different window, run Bob's chat2 instance

   ```shell
   ./build/chat2 --fleet:none --content-topic:/toy-chat/2/luzhou/proto --rln-relay:true --rln-relay-dynamic:true --rln-relay-eth-contract-address:<use-the-contract-from-step-4> --rln-relay-eth-client-address:ws://localhost:8545 --ports-shift:5 --rln-relay-eth-account-private-key:3c914dff62bd200e1e1b1af9d40eace4bc70875d1007b8cad4a950d3c7b3e442 --log-level=DEBUG --staticnode:<alice-peer-address>
   # Choose a nickname >> Bob
   ```

9. In a different window, run Carol's chat2 instance (we will use the same credentials that we used for Interep)

   ```shell
   ./build/chat2 --fleet:none --content-topic:/toy-chat/2/luzhou/proto --rln-relay:true --rln-relay-dynamic:true --rln-relay-eth-contract-address:<use-the-contract-from-step-4> --rln-relay-eth-client-address:ws://localhost:8545 --ports-shift:5 --rln-relay-id-commitment-key:<from-output-of-step-4> --rln-relay-id-key:<from-output-of-step-4> --rln-relay-membership-index:<from-output-of-step-4> --log-level=DEBUG --staticnode:<alice-peer-address>
   # Choose a nickname >> Carol
   ```

10. Now you can send messages from Carol, and they will be validated by Alice. Spam messages will be detected and dropped before relaying to Bob.

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
