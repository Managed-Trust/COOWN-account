import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import List "mo:base/List";
import Iter "mo:base/Iter";
import AccountActorClass "./Account";
import Cycles "mo:base/ExperimentalCycles";

actor GroupAccountManager {
    private var accounts : [Principal] = [];

    private stable var groupEntries : [(Text, [Principal])] = [];
    var groups = HashMap.HashMap<Text, [Principal]>(0, Text.equal, Text.hash);

    public func createAccount(accountId : Text, groupId : Text, initialBalance : Nat) : async Principal {
        Cycles.add(20_000_000_000); // Since this value increases as time passes, change this value according to error in console.

        let newAccountActor = await AccountActorClass.AccountActor(accountId, groupId, initialBalance, "", "");
        accounts := Array.append(accounts, [Principal.fromActor(newAccountActor)]);
        switch (groups.get(groupId)) {
            case (null) {
                groups.put(groupId, [Principal.fromActor(newAccountActor)]);
            };
            case (?val) {
                var newVal = Array.append(val, [Principal.fromActor(newAccountActor)]);
                groups.put(groupId, newVal);
            };
        };
        return Principal.fromActor(newAccountActor);
    };

    public query func getGroupWallets(groupId : Text) : async ?[Principal] {
        return groups.get(groupId);
    };

    public query func listAccounts() : async [Principal] {
        accounts;
    };

    public query func getAllGroups() : async [(Text, [Principal])] {
        return Iter.toArray(groups.entries());
    };

    public query func getGroupIds() : async [Text] {
        return Iter.toArray(groups.keys());
    };

    system func preupgrade() {
        groupEntries := Iter.toArray(groups.entries());

    };
    system func postupgrade() {
        groups := HashMap.fromIter<Text, [Principal]>(groupEntries.vals(), 1, Text.equal, Text.hash);
    };
};
