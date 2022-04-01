const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("VotingEngine", function () {
  let owner
  let candidate1
  let voting

  beforeEach(async function () {
    [owner, candidate1] = await ethers.getSigners()

    const VotingEngine = await ethers.getContractFactory("VotingEngine", owner)
    voting = await VotingEngine.deploy()
    await voting.deployed()
  })

  it("sets owner", async function() {
    const currentOwner = await voting.owner()
    expect(currentOwner).to.eq(owner.address) // eq = equal
  })

  async function createVoting(title = "demo") {
    const tx = await voting.addVoting(title)
    return tx
  }
  
  describe("addVoting", async function() {
    it("creates voting", async function() { // TODO: протестировать остальные атрибуты
      const title = "Demo Voting"
      await createVoting(title)
      const fetchedVoting = await voting.votings(0)
      expect(fetchedVoting.title).to.eq(title)
      expect(fetchedVoting.started).to.eq(false)
    })

    it("doesnt allow to create voting for non-owners", async function() {
      await expect(
        voting.connect(candidate1).addVoting("incorrect")
      ).to.be.revertedWith("not an owner!") // Waffle.js
    })
  })

  describe("startVoting", async function() {
    // TODO: протестировать, что нельзя запускать голосование второй раз
    // и что голосование не может запустить не-владелец
    it("starts voting", async function() {
      const title = "Demo Voting"
      const createTxVoting = await createVoting(title)

      await voting.startVoting(0)
      // 259200  --> 3 days
      const threeDays = 259200
      const fetchedVoting = await voting.votings(0)
      expect(fetchedVoting.started).to.eq(true)
      const timestamp = (
        await ethers.provider.getBlock(createTxVoting.blockNumber)
      ).timestamp

      expect(fetchedVoting.endsAt).to.eq(timestamp + threeDays + 1)
    })
  })

  describe("addCandidate", async function() {
    // TODO: проверить, что нельзя добавлять 2 раза одного и того же человека
    it("adds candidate", async function() {
      await createVoting()
      await voting.connect(candidate1).addCandidate(0)
    })

    it("doesnt allow to add candidate if voting has started", async function() {
      await createVoting()
      await voting.startVoting(0)
      await expect(
        voting.connect(candidate1).addCandidate(0)
      ).to.be.revertedWith("already started!")
    })
  })

  describe("vote", async function() {
    const requiredSum = ethers.utils.parseEther('0.01')

    beforeEach(async function () {
      await createVoting()
      await voting.connect(candidate1).addCandidate(0)
      await voting.startVoting(0)
    })

    it("allows to vote", async function() {
      await voting.vote(0, candidate1.address, {value: requiredSum})
      const currentVoting = await voting.votings(0)
      expect(currentVoting.totalAmount).to.eq(requiredSum)

      const [allCandidates, allVotes] = await voting.candidates(0)
      expect(allCandidates).to.include(candidate1.address)
      expect(allVotes[0]).to.eq(1)

      const [allParticipants, allVotedFor] = await voting.participants(0)
      expect(allParticipants).to.include(owner.address)
      expect(allVotedFor).to.include(candidate1.address)
    })
  })
})