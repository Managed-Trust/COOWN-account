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

    //=================================Arrays======================================//
    var balance : Nat = initialBalance;
    var users : [AccountUser] = [];
    var transactions : [Transaction] = [];
    var transactionLimits : [TransactionLimit] = [];
    var requiredProposals : Nat = 1;

    //=================================HashMaps======================================//
    var balanceMap = HashMap.HashMap<Principal, Float>(0, Principal.equal, Principal.hash);
    var dailyTransactions : HashMap.HashMap<Principal, Nat> = HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);
    var monthlyTransactions : HashMap.HashMap<Principal, Nat> = HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);

    //=================================Settings======================================//
    private var dailyLimit : Nat = 0;
    private var monthlyLimit : Nat = 0;
    private var isAdminOnlyMode : Bool = true; // By default, admin has all rights

    //=================================Functions======================================//

    //=================================Users Fuctions======================================//

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

    //=================================Admin Functions======================================//

    private func isAdmin(caller : Principal) : async Bool {
        return Array.find<AccountUser>(
            users,
            func(u : AccountUser) : Bool {
                return u.userId == caller and u.role == #Admin;
            },
        ) != null;
    };

    public shared (msg) func setTransactionMode(adminOnly : Bool, daily : Nat, monthly : Nat) : async Text {
        // if (await isAdmin(msg.caller)) {
        // if (true) {
            isAdminOnlyMode := adminOnly;
            dailyLimit := daily;
            monthlyLimit := monthly;
            return "Transaction mode and limits set successfully.";
        // } else {
        //     return "Only admin can set transaction mode and limits.";
        // };
    };

    //=================================Transaction Handling======================================//
    //Board of directors
    //Voting
    //Email Based Voting // Email managemenet 
    // OPT code for security
    public shared (msg) func recordTransaction(amount : Nat, description : Text) : async Text {
        let currentDay = Time.now() / (24 * 60 * 60); // Calculate the current day
        let currentMonth = Time.now() / (30 * 24 * 60 * 60); // Calculate the current month

        // Retrieve daily and monthly transactions for the user
        let dailyAmount = switch (dailyTransactions.get(msg.caller)) {
            case (null) { 0 };
            case (?amt) { amt };
        };

        let monthlyAmount = switch (monthlyTransactions.get(msg.caller)) {
            case (null) { 0 };
            case (?amt) { amt };
        };
        let store = await isAdmin(msg.caller);
        if (isAdminOnlyMode and store) {
            // Admin can bypass limits and approvals in Admin-Only Mode
            return processTransaction(amount, description);
        } else if ((dailyAmount + amount <= dailyLimit) and (monthlyAmount + amount <= monthlyLimit)) {
            // User is within limits, proceed with the transaction
            return processTransaction(amount, description);
        } else {
            // Transaction exceeds limits, needs approval
            return "Transaction exceeds limit, approval required.";
        };
    };

    // Helper function to process the transaction
    private func processTransaction(amount : Nat, description : Text) : Text {
        // Here is where you would update the balance and record the transaction
        balance := balance + amount;
        transactions := Array.append(transactions, [{ accountId = accountId; groupId = groupId; amount = amount; timestamp = Time.now(); description = description; approvedBy = [] }]);

        return "Transaction recorded successfully.";
    };

    // Approve a transaction
    public shared (msg) func approveTransaction(transactionIndex : Nat) : async Text {
        if (transactionIndex >= Array.size(transactions)) {
            return "Transaction does not exist.";
        };

        let transaction = transactions[transactionIndex];
        let store = await isAdmin(msg.caller);
        if (isAdminOnlyMode and store) {
            // Admin can approve and execute transactions directly in Admin-Only Mode
            balance -= transaction.amount;
            return "Transaction approved and executed by admin.";
        } else if (await isUserApproved(transaction.approvedBy)) {
            return "You have already approved this transaction.";
        } else {
            // Add the caller to the list of approvers
            let updatedTransaction = {
                transaction with
                approvedBy = Array.append(transaction.approvedBy, [msg.caller])
            };

            // Update the transactions array
            transactions := Array.tabulate<Transaction>(
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
                balance -= transaction.amount;
                return "Transaction approved and executed.";
            } else {
                return "Transaction approved but pending further approvals.";
            };
        };
    };

    public shared (msg) func isUserApproved(approvedBy : [Principal]) : async Bool {
        return Array.find(
            approvedBy,
            func(id : Principal) : Bool {
                return id == msg.caller;
            },
        ) != null;
    };

    public shared (msg) func setRequiredProposals(newRequiredProposals : Nat) : async Text {
        // Only allow the admin to set the required number of proposals
        if (await isAdmin(msg.caller)) {
            requiredProposals := newRequiredProposals;
            return "Required number of proposals updated successfully.";
        } else {
            return "Error: Only admin can set the required number of proposals.";
        };
    };
    private func requiredApprovals() : Nat {
        return requiredProposals;
    };
    //=============================================================================================//
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

    // Placeholder function to update user balance
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
