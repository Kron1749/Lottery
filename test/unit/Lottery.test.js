const { expect, assert } = require("chai")
const { deployments, ethers, getNamedAccounts, network } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Lottery", async () => {
          let lottery
          let deployer
          let accounts
          let VRFCoordinatorV2Mock
          let lotteryEntranceFee
          let interval
          let player
          beforeEach(async () => {
              accounts = await ethers.getSigners() // On local network will get 10 fake accounts
              deployer = (await getNamedAccounts()).deployer
              player = accounts[1]
              await deployments.fixture(["mocks", "lottery"]) // This will deploy everything on our local network
              VRFCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
              lotteryContract = await ethers.getContract("Lottery") // Will get the recent deployment
              lottery = lotteryContract.connect(player)
              lotteryEntranceFee = await lottery.getMinimumValue()
              interval = await lottery.getInterval()
          })
          describe("Constructor", async () => {
              it("Initialize the lottery correctly", async () => {
                  const raffleState = (await lottery.getLotteryState()).toString()
                  assert.equal(raffleState, "0")
              })
          })
          describe("Enter the lottery", async () => {
              it("Can't enter if value is not enough", async () => {
                  await expect(lottery.enterTheLottery()).to.be.revertedWith("Raffle__SendMoreToEnterRaffle")
              })
              it("Can't enter the lottery if closed", async () => {
                  await lottery.enterTheLottery({ value: lotteryEntranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1]) //Here we increase the time
                  await network.provider.request({ method: "evm_mine", params: [] }) // We sent trx,now we need to mine it
                  await lottery.performUpkeep([])
                  await expect(lottery.enterTheLottery({ value: lotteryEntranceFee })).to.be.revertedWith(
                      "Raffle__RaffleNotOpen"
                  )
              })
              it("Should push the player to array,if he entered lottery", async () => {
                  await lottery.enterTheLottery({ value: lotteryEntranceFee })
                  const player = lottery.getPlayer(0)
                  assert.equal(deployer.address, player.address)
              })
          })
          describe("CheckUpKeep", async () => {
              it("Returns false if time hasn't passed", async () => {
                  await lottery.enterTheLottery({ value: lotteryEntranceFee })
                  const { upkeepNeeded } = lottery.callStatic.checkUpkeep("0x") // Use callStatic only to execute this trx
                  assert.notEqual(upkeepNeeded, true)
              })
              it("Returns false if no players", async () => {
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  const { upkeepNeeded } = lottery.callStatic.checkUpkeep("0x") // Use callStatic only to execute this trx
                  assert.notEqual(upkeepNeeded, true)
              })
              it("Returns false if lottery state is't open", async () => {
                  await lottery.enterTheLottery({ value: lotteryEntranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  await lottery.performUpkeep([])
                  const lotteryState = await lottery.getLotteryState()
                  const { upkeepNeeded } = await lottery.callStatic.checkUpkeep("0x") // upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers)
                  assert.equal(lotteryState.toString() == "1", upkeepNeeded == false)
              })
              it("Returns false if lottery has no balance", async () => {
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  const { upkeepNeeded } = lottery.callStatic.checkUpkeep("0x") // Use callStatic only to execute this trx
                  assert.notEqual(upkeepNeeded, true)
              })
              it("Returns true if everything is okay", async () => {
                  await lottery.enterTheLottery({ value: lotteryEntranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  const { upkeepNeeded } = lottery.callStatic.checkUpkeep("0x")
                  assert.notEqual(upkeepNeeded, false)
              })
          })
          describe("PerformUpKeep", async () => {
              it("Runs if checkUpKeep is true", async () => {
                  await lottery.enterTheLottery({ value: lotteryEntranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  const tx = await lottery.performUpkeep("0x")
                  assert(tx)
              })
              it("Revert if checkUpKeep is not true", async () => {
                  await expect(lottery.performUpkeep("0x")).to.be.revertedWith("Raffle__UpkeepNotNeeded")
              })
              it("Update the lottery state", async () => {
                  await lottery.enterTheLottery({ value: lotteryEntranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  const trxResponse = await lottery.performUpkeep("0x")
                  const trxReceipt = await trxResponse.wait(1)
                  const lotteryState = await lottery.getLotteryState()
                  assert(lotteryState == 1)
              })
          })
          describe("FullFillRandomWords", async () => {
              beforeEach(async () => {
                  await lottery.enterTheLottery({ value: lotteryEntranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
              })
              it("Could only be called after PerformUpKeep", async () => {
                  await expect(VRFCoordinatorV2Mock.fulfillRandomWords(0, lottery.address)).to.be.revertedWith(
                      "nonexistent request"
                  )
                  await expect(VRFCoordinatorV2Mock.fulfillRandomWords(1, lottery.address)).to.be.revertedWith(
                      "nonexistent request"
                  )
              })
              it("Picks winner,resets,send money", async () => {
                  const additionalEntrants = 3
                  const startingAccountIndex = 2 // deployer = 0
                  for (let i = startingAccountIndex; i < startingAccountIndex + additionalEntrants; i++) {
                      const accountConnectedLottery = lottery.connect(accounts[i])
                      await accountConnectedLottery.enterTheLottery({ value: lotteryEntranceFee })
                  }
                  const startingTimeStamp = await lottery.getLastTimeStamp()
                  await new Promise(async (resolve, reject) => {
                      lottery.once("WinnerPicked", async () => {
                          try {
                              const recentWinner = await lottery.getRecentWinner() //acc[2]
                              const lotteryState = await lottery.getLotteryState()
                              const endingTimeStamp = await lottery.getLastTimeStamp()
                              const numPlayers = await lottery.getNumberOfPlayers()
                              const winnerEndingBalance = await accounts[2].getBalance()
                              assert.equal(numPlayers.toString(), "0")
                              assert.equal(lotteryState.toString(), "0")
                              assert(endingTimeStamp > startingTimeStamp)
                              assert.equal(
                                  winnerEndingBalance.toString(),
                                  winnerStartingBalance.add(
                                      lotteryEntranceFee.mul(additionalEntrants).add(lotteryEntranceFee).toString()
                                  )
                              )
                              resolve()
                          } catch (e) {
                              reject(e)
                          }
                      })
                      const tx = await lottery.performUpkeep("0x")
                      const txReceipt = await tx.wait(1)
                      const winnerStartingBalance = await accounts[2].getBalance()
                      await VRFCoordinatorV2Mock.fulfillRandomWords(txReceipt.events[1].args.requestId, lottery.address)
                  })
              })
          })
      })
