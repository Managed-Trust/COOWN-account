import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Int64 "mo:base/Int64";
import Int "mo:base/Int";
import Nat32 "mo:base/Nat32";
import Int32 "mo:base/Int32";
import Array "mo:base/Array";
import Float "mo:base/Float";
import AccountActor "./Account";

actor GroupAccountManager {

  type AccountUser = {
    userId : Text;
    status : Text; // For example: "active", "inactive", "pending", etc.
    ownership : Float; // Percentage of ownership represented as a float (e.g., 0.5 for 50%)
  };

  type Account = {
    accountId : Text; // Unique identifier for each account
    groupId : Text;
    users : [AccountUser]; // List of users associated with the account
    balance : Nat; // For financial accounts, use 'Nat' to ensure non-negative values.
    created : Int; // Timestamp for account creation
  };

  type Transaction = {
    accountId : Text; // Identifier of the account involved in the transaction
    groupId : Text;
    amount : Int; // Can be negative for deductions
    timestamp : Int;
    description : Text;
  };
  // HashMap to store accounts by group ID
  var accounts = HashMap.HashMap<Text, Account>(0, Text.equal, Text.hash);

  // HashMap to store list of transactions by group ID
  var transactions = HashMap.HashMap<Text, [Transaction]>(0, Text.equal, Text.hash);

  // // Function to create a new account for a group
  public func createAccount(accountId : Text, groupId : Text, initialBalance : Nat) : async Text {
    switch (accounts.get(groupId)) {
      case (null) {
        let newAccount = {
          groupId = groupId;
          accountId = accountId;
          users = [];
          balance = initialBalance;
          created = Time.now();
        };
        accounts.put(groupId, newAccount);
        return "Account created successfully.";
      };
      case (_) {
        return "Account already exists for this group.";
      };
    };
  };

  // Function to record a transaction
  public func recordTransaction(accountId : Text, groupId : Text, amount : Int, description : Text) : async Text {
    switch (accounts.get(groupId)) {
      case (null) {
        return "No account found for this group.";
      };
      case (?acc) {
        let newTransaction = {
          accountId = accountId;
          groupId = groupId;
          amount = amount;
          timestamp = Time.now();
          description = description;
        };

        let absAmount = if (amount < 0) { -amount } else { amount };
        let updatedBalance = acc.balance + absAmount;
        let updatedBalanceNat : Nat = Int.abs(updatedBalance);
        let updatedAccount = {
          acc with balance = updatedBalanceNat;
        };
        accounts.put(groupId, updatedAccount);
        switch (transactions.get(groupId)) {
          case (null) {
            transactions.put(groupId, [newTransaction]);
          };
          case (?val) {
            var ts = val;
            ts := Array.append(ts, [newTransaction]);
            transactions.put(groupId, ts);
          };
        };

        return "Transaction recorded successfully.";
      };
    };
  };

  // Function for code

  public func updateUserStatus(accountId : Text, userId : Text, newStatus : Text) : async Text {
    switch (accounts.get(accountId)) {
      case (null) { return "Account not found." };
      case (?acc) {
        let updatedUsers = Array.map<AccountUser, AccountUser>(
          acc.users,
          func(u : AccountUser) : AccountUser {
            if (u.userId == userId) {
              return { u with status = newStatus };
            } else {
              return u;
            };
          },
        );
        let updatedAccount = { acc with users = updatedUsers };
        accounts.put(accountId, updatedAccount);
        return "User status updated successfully.";
      };
    };
  };
  public func addUserToAccount(
    accountId : Text,
    userId : Text,
    status : Text,
    ownership : Float,
  ) : async Text {
    switch (accounts.get(accountId)) {
      case (null) { return "Account not found." };
      case (?acc) {
        // Check if user already exists using Array.find
        let userExists = Array.find(
          acc.users,
          func(u : AccountUser) : Bool {
            return u.userId == userId;
          },
        );

        if (userExists != null) {
          return "User already exists in the account.";
        };

        // Add new user
        let updatedUsers = Array.append(acc.users, [{ userId = userId; ownership = ownership; status = status }]);
        let updatedAccount = {
          acc with users = updatedUsers;
        };
        accounts.put(accountId, updatedAccount);
        return "User added successfully.";
      };
    };
  };

  // Function to get account details
  public query func getAccount(groupId : Text) : async ?Account {
    return accounts.get(groupId);
  };

  // Function to get transaction history
  public query func getTransactions(groupId : Text) : async ?[Transaction] {
    return transactions.get(groupId);
  };
};
