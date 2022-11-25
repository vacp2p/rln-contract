export const devNets = [
    'hardhat',
    'localhost',
    'goerli',
]

export const prodNets = ['mainnet']

export const isDevNet = (networkName: string) => devNets.includes(networkName)