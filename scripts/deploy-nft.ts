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
    const NFT = await ethers.getContractFactory('NFT');
    const _nft: any = await NFT.deploy(
      deployer.address,
      '0xa8cD42e8Cb03DeC97acBda75595B37319db1bD53' // erc20 address
    );

    console.log('nft deployed to:', _nft.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
