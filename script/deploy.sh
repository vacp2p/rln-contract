#!/bin/bash

set -e

contract_name="$1"

if [ -z "$contract_name" ]; then
  echo "Usage: ./script/deploy.sh <contract_name>"
  exit 1
fi

echo "Sourcing .env"
source .env

# Check if appropriate env vars are set
if [ -z "$RPC_URL" ]; then
  echo "RPC_URL is not set"
  exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
  echo "PRIVATE_KEY is not set"
  exit 1
fi

echo "Deploying $contract_name..."

# Deploy the contract
if [ "$contract_name" = "rln" ]; then
  chain_id=$(cast chain-id --rpc-url "$RPC_URL")

  chain_name=""
  verifier_url=""
  if [ -z "$chain_id" ]; then
    echo "Failed to get chain id"
    exit 1
  fi

  if [ "$chain_id" = "11155111" ]; then
    chain_name="sepolia"
  else
    echo "Invalid chain id, try again with sepolia"
    exit 1
  fi


  forge script script/Deploy.s.sol:Deploy --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast -v --json
  echo "Deployed Rln contracts, Now verifying"

  # Get the PoseidonT3 contract address from ./broadcast/Deploy.s.sol/$chain_id/run-latest.json
  poseidon_t3_name=$(cat ./broadcast/Deploy.s.sol/$chain_id/run-latest.json | jq -r '.["transactions"][0]["contractName"]')
  poseidon_t3_address=$(cat ./broadcast/Deploy.s.sol/$chain_id/run-latest.json | jq -r '.["transactions"][0]["contractAddress"]')

  echo "Verifying $poseidon_t3_name library"
  forge verify-contract $poseidon_t3_address --chain $chain_name $poseidon_t3_name --watch

  # Get the BinaryIMT contract address from ./broadcast/Deploy.s.sol/$chain_id/run-latest.json
  binary_imt_name=$(cat ./broadcast/Deploy.s.sol/$chain_id/run-latest.json | jq -r '.["transactions"][1]["contractName"]')
  binary_imt_address=$(cat ./broadcast/Deploy.s.sol/$chain_id/run-latest.json | jq -r '.["transactions"][1]["contractAddress"]') 

  echo "Verifying $binary_imt_name library"
  forge verify-contract --libraries "poseidon-solidity/PoseidonT3.sol:$poseidon_t3_name:$poseidon_t3_address" $binary_imt_address --chain $chain_name $binary_imt_name --watch

  # Get the Verifier contract address from ./broadcast/Deploy.s.sol/$chain_id/run-latest.json
  verifier_name=$(cat ./broadcast/Deploy.s.sol/$chain_id/run-latest.json | jq -r '.["transactions"][2]["contractName"]')
  verifier_address=$(cat ./broadcast/Deploy.s.sol/$chain_id/run-latest.json | jq -r '.["transactions"][2]["contractAddress"]')

  echo "Verifying $verifier_name library"
  forge verify-contract $verifier_address --chain $chain_name $verifier_name --watch

  # Get the Rln contract address from ./broadcast/Deploy.s.sol/$chain_id/run-latest.json
  rln_name=$(cat ./broadcast/Deploy.s.sol/$chain_id/run-latest.json | jq -r '.["transactions"][3]["contractName"]')
  rln_address=$(cat ./broadcast/Deploy.s.sol/$chain_id/run-latest.json | jq -r '.["transactions"][3]["contractAddress"]')

  echo "Verifying $rln_name library"
  forge verify-contract \
    $rln_address \
    --libraries "poseidon-solidity/PoseidonT3.sol:$poseidon_t3_name:$poseidon_t3_address" \
    --libraries "@zk-kit/imt.sol/BinaryIMT.sol:$binary_imt_name:$binary_imt_address" \
    --chain $chain_name \
    $rln_name \
    --watch \
    --constructor-args $(cast abi-encode "constructor(uint256,uint256,address)" 0 20 "$verifier_address")

  echo "Verified $rln_name contract, now dumping the artifacts to ./deployments/$chain_id/latest.json"

  # Dump the artifacts to ./deployments/$chain_id/latest.json
  mkdir -p ./deployments/$chain_id
  cat ./broadcast/Deploy.s.sol/$chain_id/run-latest.json | jq -r '.["transactions"]' > ./deployments/$chain_id/latest.json
else
  echo "Invalid contract name, please use rln."
fi