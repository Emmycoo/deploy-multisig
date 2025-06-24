import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "Multisig Wallet: Initialize wallet with multiple owners",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        const block = chain.mineBlock([
            Tx.contractCall('multisig-wallet', 'initialize-wallet', [
                types.list([
                    types.principal(deployer.address),
                    types.principal(wallet1.address),
                    types.principal(wallet2.address)
                ]),
                types.uint(2)
            ], deployer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk().expectBool(true);
    }
});

Clarinet.test({
    name: "Multisig Wallet: Propose and sign transaction",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // First, initialize the wallet
        chain.mineBlock([
            Tx.contractCall('multisig-wallet', 'initialize-wallet', [
                types.list([
                    types.principal(deployer.address),
                    types.principal(wallet1.address),
                    types.principal(wallet2.address)
                ]),
                types.uint(2)
            ], deployer.address)
        ]);

        // Propose a transaction
        const block = chain.mineBlock([
            Tx.contractCall('multisig-wallet', 'propose-transaction', [
                types.principal(wallet1.address),
                types.uint(1000000),
                types.uint(2)
            ], deployer.address),
            
            // Sign the transaction
            Tx.contractCall('multisig-wallet', 'sign-transaction', [
                types.uint(0)
            ], wallet1.address)
        ]);

        assertEquals(block.receipts.length, 2);
        block.receipts[0].result.expectOk().expectUint(0);
        block.receipts[1].result.expectOk().expectBool(true);
    }
});