const { getNamedAccounts, deployments, network } = require("hardhat")
const { networkConfig, developmentChains, VERIFICATION_BLOCK_CONFIRMATIONS } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

const FUND_AMOUNT = "1000000000000000000000"

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    let vrfCoordinatorV2Address, subscriptionId

    // Deploying vrf coordinator
    if (chainId == 31337) {
        const vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
        vrfCoordinatorV2Address = vrfCoordinatorV2Mock.address
        const trxResponse = await vrfCoordinatorV2Mock.createSubscription()
        const trxReceipt = await trxResponse.wait()
        subscriptionId = trxReceipt.events[0].args.subId
        await vrfCoordinatorV2Mock.fundSubscription(subscriptionId, FUND_AMOUNT)
    } else {
        vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2"]
        subscriptionId = networkConfig[chainId]["subscriptionId"]
    }

    const waitBlockConfirmations = developmentChains.includes(network.name) ? 1 : VERIFICATION_BLOCK_CONFIRMATIONS

    // Deploying contract
    const arguments = [
        vrfCoordinatorV2Address,
        subscriptionId,
        networkConfig[chainId]["callbackGasLimit"],
        networkConfig[chainId]["gasLane"],
        networkConfig[chainId]["keepersUpdateInterval"],
    ]
    const lottery = await deploy("Lottery", {
        from: deployer,
        args: arguments,
        log: true,
        waitConfirmations: waitBlockConfirmations,
    })
    // Contract verifying
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        // If we are on a testnet
        await verify(lottery.address, arguments)
    }
}
module.exports.tags = ["all", "fundme"]
