var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "bone more want coil chase green gorilla water body capital guilt virus";

module.exports = {
  networks: {
    // development: {
    //   provider: function() {
    //     return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/", 0, 50);
    //   },
    //   network_id: '*',
    //   gas: 6500000
    // }
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: '*',
      gas: 6500000
    }
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};