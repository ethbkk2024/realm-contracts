import {ethers} from 'hardhat';

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    // We get the contract to deploy

    const [deployer]: any = await ethers.getSigners();
    console.log(`account: ${deployer.address}`);
    const GameSystem = await ethers.getContractFactory('GameSystem');
    const _gameSystem: any = await GameSystem.deploy(
      '0xc3f0e6018c8A115de3e0734e741C170E03C0aBd4', // realm token
      '0xDEbD08dD538b541093b5aCdCa52a2040c0aB9D1A', // nft
      deployer.address, // game server address
      deployer.address // owner
    );

    console.log('gameSystem deployed to:', _gameSystem.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
