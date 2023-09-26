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

## Test with Interep UI deployed on Goerli/other testnets

1. Fund an address with Goerli ETH from https://goerlifaucet.com

2. Fetch dependencies

   ```shell
   yarn
   ```

3. Set the private key of the funded address into the env of a terminal window

   ```shell
   export PRIVATE_KEY=<your-private-key>
   ```

4. Navigate to https://goerli.interep.link

5. Connect your wallet (using the funded address)

6. Follow the instructions to authorize a web2 provider of your choice. Note that only Github and Reddit are supported by RLN.

   - Note the provider name and reputation you have
   - Wait 2 minutes for the transaction containing your registration to be mined

7. In the open terminal window, run

   ```shell
   yarn proof <web2 provider name> <web2 reputation> goerli
   ```

8. In a new terminal window, run

   ```
   yarn ui
   ```

   - If `http-server` is missing, `yarn global add http-server` will resolve the issue.

9. Navigate to http://127.0.0.1:8080

10. Connect your wallet and fetch the contract state from the blockchain

11. Scroll down to the "Or use credentials you generated elsewhere:" section, and add the credentials obtained in step 7.

12. Scroll down and select "With semaphore proof"

13. Add the proof values from obtained in step 7

14. Click "Register with Proof"

15. Approve the transaction

16. In a new terminal window, Clone [nwaku](https://github.com/waku-org/nwaku) and switch to the `rln-interep-poc` branch

17. Run

```shell
make -j8 wakunode2 RLN=true && ./build/wakunode2 --rln-relay-content-topic:/toy-chat/2/luzhou/proto \
                                                 --rln-relay:true \
                                                 --rln-relay-dynamic:true \
                                                 --rln-relay-eth-contract-address:0xCd41a0aC28c5c025779eAC3208D0bF23baa3a5b6 \
                                                 --rln-relay-eth-client-address:ws://<goerli-rpc-url> \
                                                 --ports-shift=22 \
                                                 --log-level=DEBUG \
                                                 --dns-discovery \
                                                 --dns-discovery-url:enrtree://ANEDLO25QVUGJOUTQFRYKWX6P4Z4GKVESBMHML7DZ6YK4LGS5FC5O@prod.wakuv2.nodes.status.im \
                                                 --discv5-discovery:true \
                                                 --lightpush \
                                                 --filter \
                                                 --websocket-support \
                                                 --websocket-port:8000
```

- Make note of the node's multiaddr. It should look something like `/ip4/172.13.4.12/tcp/8022/ws/p2p/16Uiu2HAkvWiyFsgRhuJEb9JfjYxEkoHLgnUQmr1N5mKWnYjxYRVm`

18. In the browser, Add the multiaddr you obtained in step 17.

19. Choose a nickname, and send messages!

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
