import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";
import Float "mo:base/Float";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";

actor class AccountActor(accountId : Text, groupId : Text, initialBalance : Nat, groupType : Text, groupLevel : Text) {

    //=================================Types======================================//
    type Role = {
        #Admin;
        #Owner;
        #Member;
    };

    type AccountUser = {
        userId : Principal; // Using Principal to uniquely identify users
        role : Role;
        ownership : Float; // Ownership percentage
    };

    type Transaction = {
        accountId : Text;
        groupId : Text;
        amount : Nat;
        timestamp : Int;
        description : Text;
        approvedBy : [Principal]; // List of users who approved this transaction
    };

    type TransactionLimit = {
        limitId : Text;
        amount : Nat;
        approvedBy : [Principal];
    };

    type LimitApproval = {
        limitId : Text;
        limit : Nat;
        approvers : [Principal];
    };

    //=================================Arrays======================================//

    var balance : Nat = initialBalance;
    var users : [AccountUser] = [];
    var transactions : [Transaction] = [];
    var transactionLimits : [TransactionLimit] = [];

    //=================================HashMaps======================================//

    var balanceMap = HashMap.HashMap<Principal, Float>(0, Principal.equal, Principal.hash);
    var dailyTransactions = HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);
    var monthlyTransactions = HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);

    //=================================Functions==========================================//

    //=================================Users Fuctions======================================//

    private var dailyLimit : Nat = 0;
    private var monthlyLimit : Nat = 0;

    

    // public func setTransactionLimits(daily : Nat, monthly : Nat) : async Text {
    //     if (await isAdmin(msg.caller)) {
    //         dailyLimit := daily;
    //         monthlyLimit := monthly;
    //         return "Transaction limits set successfully.";
    //     } else {
    //         return "Only admin can set transaction limits.";
    //     };
    // };

    public func addUser(userId : Principal, role : Role, ownership : Float) : async Text {
        let userExists = Array.find(
            users,
            func(u : AccountUser) : Bool {
                return u.userId == userId;
            },
        );

        if (userExists != null) {
            return "User already exists in the account.";
        } else {
            users := Array.append(users, [{ userId = userId; role = role; ownership = ownership }]);
            return "User added successfully.";
        };
    };

    public func updateUserRole(userId : Principal, newRole : Role) : async Text {
        var updatedUsers = Array.map<AccountUser, AccountUser>(
            users,
            func(u : AccountUser) : AccountUser {
                if (u.userId == userId) {
                    { u with role = newRole };
                } else {
                    u;
                };
            },
        );

        users := updatedUsers;
        return "User role updated.";
    };

    public query func getAllUsers() : async [AccountUser] {
        return users;
    };

    public query func getAccountDetails() : async (Nat, [AccountUser], [Transaction]) {
        return (balance, users, transactions);
    };

    //=================================Transaction Fuctions======================================//

    public func recordTransaction(amount : Nat, description : Text) : async Text {
        let newTransaction : Transaction = {
            accountId = accountId;
            groupId = groupId;
            amount = amount;
            timestamp = Time.now();
            description = description;
            approvedBy = [];
        };

        // let absAmount = if (amount < 0) { -amount } else { amount };

        let absAmount = if (amount < 0) { -amount } else { amount };
        let updatedBalance = balance + absAmount;
        let updatedBalanceNat : Nat = Int.abs(updatedBalance);
        let updatedAbs : Nat = Int.abs(absAmount);

        if (amount < 0 and balance < updatedAbs) {
            return "Insufficient balance.";
        } else {
            balance := if (amount < 0) { balance - updatedAbs } else {
                balance + updatedAbs;
            };
            transactions := Array.append(transactions, [newTransaction]);
            return "Transaction recorded successfully.";
        };
        return "success";
    };

    public shared (msg) func approveTransaction(transactionIndex : Nat) : async Text {
        if (transactionIndex >= Array.size(transactions)) {
            return "Transaction does not exist.";
        };

        let transaction = transactions[transactionIndex];

        if (await isUserApproved(transaction.approvedBy)) {
            return "You have already approved this transaction.";
        };

        // Calculate absolute value manually
        let absAmount : Nat = if (transaction.amount < 0) {
            let store = 0 - transaction.amount;
        } else {
            transaction.amount;
        };

        if (balance < absAmount) {
            return "Insufficient balance.";
        };

        // Add the caller to the list of approvers
        let updatedTransaction = {
            transaction with
            approvedBy = Array.append(transaction.approvedBy, [msg.caller])
        };

        // Create a new array with the updated transaction
        let updatedTransactions = Array.tabulate<Transaction>(
            Array.size(transactions),
            func(index : Nat) : Transaction {
                if (index == transactionIndex) {
                    return updatedTransaction;
                } else {
                    return transactions[index];
                };
            },
        );

        if (Array.size(updatedTransaction.approvedBy) >= requiredApprovals()) {
            balance -= absAmount;
            transactions := updatedTransactions;
            return "Transaction approved and executed.";
        } else {
            transactions := updatedTransactions;
            return "Transaction approved but pending further approvals.";
        };
    };

    // // Helper function to check if the user can initiate a transaction
    public shared (msg) func canInitiateTransaction() : async Bool {
        return Array.find(
            users,
            func(u : AccountUser) : Bool {
                return u.userId == msg.caller and (u.role == #Admin or u.role == #Owner);
            },
        ) != null;
    };

    public shared (msg) func isUserApproved(approvedBy : [Principal]) : async Bool {
        return Array.find(
            approvedBy,
            func(id : Principal) : Bool {
                return id == msg.caller;
            },
        ) != null;
    };

    // // Determine the required number of approvals
    private func requiredApprovals() : Nat {
        let adminCount = Array.size(
            Array.filter(
                users,
                func(u : AccountUser) : Bool {
                    return u.role == #Admin;
                },
            )
        );
        return if (adminCount > 1) { adminCount } else { 1 };
    };

    public shared (msg) func approveTransaction2(transactionIndex : Nat) : async Text {
        if (transactionIndex >= Array.size(transactions)) {
            return "Transaction does not exist.";
        };

        let transaction = transactions[transactionIndex];

        if (await isUserApproved(transaction.approvedBy)) {
            return "You have already approved this transaction.";
        };

        let absAmount : Nat = transaction.amount; // Already a positive Nat value

        if (balance < absAmount) {
            return "Insufficient balance.";
        };

        // Add the caller to the list of approvers
        let updatedTransaction = {
            transaction with
            approvedBy = Array.append(transaction.approvedBy, [msg.caller])
        };

        // Update the transactions array
        let updatedTransactions = Array.tabulate<Transaction>(
            Array.size(transactions),
            func(index : Nat) : Transaction {
                if (index == transactionIndex) {
                    return updatedTransaction;
                } else {
                    return transactions[index];
                };
            },
        );

        let requiredApprovalCount = requiredApprovals();

        if (Array.size(updatedTransaction.approvedBy) >= requiredApprovalCount) {
            balance -= absAmount;
            transactions := updatedTransactions;
            return "Transaction approved and executed.";
        } else {
            transactions := updatedTransactions;
            return "Transaction approved but pending further approvals.";
        };
    };

    public func proposeTransactionLimit(limitId : Text, limitAmount : Nat) : async Text {
        let newLimit : TransactionLimit = {
            limitId = limitId;
            amount = limitAmount;
            approvedBy = [];
        };
        transactionLimits := Array.append(transactionLimits, [newLimit]);
        return "Transaction limit proposed successfully.";
    };

    public shared (msg) func approveTransactionLimit(limitId : Text) : async Text {
        let limitOpt = Array.find<TransactionLimit>(
            transactionLimits,
            func(limit : TransactionLimit) : Bool {
                limit.limitId == limitId;
            },
        );

        switch (limitOpt) {
            case (null) { return "Limit not found." };
            case (?limit) {
                // Now find the index of this limit object
                let limitIndexOpt = Array.indexOf<TransactionLimit>(
                    limit,
                    transactionLimits,
                    func(a : TransactionLimit, b : TransactionLimit) : Bool {
                        a.limitId == b.limitId;
                    },
                );

                switch (limitIndexOpt) {
                    case (null) {
                        return "Unexpected error: Limit not found after initial find.";
                    };
                    case (?limitIndex) {
                        if (await isUserApproved(limit.approvedBy)) {
                            return "You have already approved this limit.";
                        };

                        let updatedLimit = {
                            limit with
                            approvedBy = Array.append(limit.approvedBy, [msg.caller])
                        };

                        // Create a new array with the updated limit at the correct index
                        transactionLimits := Array.tabulate<TransactionLimit>(
                            Array.size(transactionLimits),
                            func(i : Nat) : TransactionLimit {
                                if (i == limitIndex) {
                                    updatedLimit;
                                } else {
                                    transactionLimits[i];
                                };
                            },
                        );

                        let requiredApprovalCount = requiredApprovals();

                        if (Array.size(updatedLimit.approvedBy) >= requiredApprovalCount) {
                            return "Transaction limit approved and updated.";
                        } else {
                            return "Transaction limit approved but pending further approvals.";
                        };
                    };
                };
            };
        };
    };

    public func distributeDividends() : async Text {
        // Calculate the total ownership by summing up all user ownership values
        let totalOwnership = Array.foldLeft<AccountUser, Float>(
            users,
            0.0,
            func(acc : Float, user : AccountUser) : Float {
                acc + user.ownership;
            },
        );

        if (totalOwnership == 0.0) {
            return "No ownership defined.";
        };

        // Convert balance to Float by first converting to Int and then to Float
        let dividendPerOwnership : Float = Float.fromInt(balance);

        // Calculate dividend per ownership unit
        let dividendPerOwnership1 = dividendPerOwnership / totalOwnership;

        // Iterate over users and calculate dividend amounts
        for (user in users.vals()) {
            let dividendAmount = dividendPerOwnership1 * user.ownership;

            // Here you would normally transfer or record the dividend amount for each user
            // Example: updateUserBalance(user.userId, dividendAmount);
            // This example assumes a function updateUserBalance exists to handle the balance update.
        };

        return "Dividends distributed successfully.";
    };

    public func distributeDividends2() : async Text {
        // Calculate the total ownership by summing up all user ownership values
        let totalOwnership = Array.foldLeft<AccountUser, Float>(
            users,
            0.0,
            func(acc : Float, user : AccountUser) : Float {
                acc + user.ownership;
            },
        );

        if (totalOwnership == 0.0) {
            return "No ownership defined.";
        };

        // Convert balance to Float
        let dividendPerOwnership : Float = Float.fromInt(balance);

        // Calculate dividend per ownership unit
        let dividendPerOwnership1 = dividendPerOwnership / totalOwnership;

        // Iterate over users and calculate dividend amounts
        for (user in users.vals()) {
            let dividendAmount = dividendPerOwnership1 * user.ownership;

            // Here you update the user's balance with the calculated dividend
            let result = await updateUserBalance(user.userId, dividendAmount);
            if (result != "Success") {
                return "Failed to distribute dividends to user:";
            };
        };

        return "Dividends distributed successfully.";
    };

    private func updateUserBalance(userId : Principal, amount : Float) : async Text {
        // Retrieve the current balance of the user
        let currentBalance = balanceMap.get(userId);

        // Calculate the new balance
        let newBalance = switch (currentBalance) {
            case (null) { amount }; // If no existing balance, set the balance to the amount
            case (?balance) { balance + amount }; // Add the amount to the existing balance
        };

        // Update the user's balance in the HashMap
        balanceMap.put(userId, newBalance);

        // Return a success message
        return "Success";
    };

    //=================================Reports======================================//

    public query func generatePerformanceReport() : async Text {
        var report = "Performance Report:\n";

        for (transaction in transactions.vals()) {
            report #= "Transaction: " # transaction.description # "\n";
        };

        report #= "Current Balance: " # Nat.toText(balance) # "\n";
        return report;
    };

    public query func generateTaxReport() : async Text {
        var report = "Tax Report:\n";

        for (transaction in transactions.vals()) {
            if (transaction.amount > 0) {
                report #= "Income: " # Nat.toText(transaction.amount) # "\n";
            } else {
                report #= "Expense: " # Nat.toText(transaction.amount) # "\n";
            };
        };

        return report;
    };

};
