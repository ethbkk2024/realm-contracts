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
    const RealmToken = await ethers.getContractFactory('RealmToken');
    const _realmToken: any = await RealmToken.deploy(deployer.address);

    console.log('token deployed to:', _realmToken.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
