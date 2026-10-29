using System.Text.Json;
using System.Text.Json.Nodes;
using Gua.Testing;
using Gua.Testing.Godot;
using NUnit.Framework;
using NUnit.Framework.Interfaces;

namespace Guild.Regression;

// Only game concerns live here. GodotSceneTestHost owns source-scene launch,
// connection, correlated locator operations and process disposal.
[TestFixture, NonParallelizable, Category("SourceRegression")]
public sealed class GuildTests
{
    GodotSceneTestHost? host;
    string evidence = "";
    string save = "";
    string? lastObserve;
    string[] expectedBugs = [];
    static string Root => FindRoot();
    static string FindRoot()
    {
        var dir = new DirectoryInfo(TestContext.CurrentContext.TestDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "project.godot"))) dir = dir.Parent;
        return dir?.FullName ?? throw new InvalidOperationException("project.godot missing");
    }
    void Open(string? bug = null)
    {
        var args = new List<string> { "--", $"--save-path={save}" };
        if (bug != null) args.Add($"--bug={bug}");
        host = GodotSceneTestHost.Load("res://main.tscn", new()
        {
            ProjectPath = Root, GodotExecutablePath = Environment.GetEnvironmentVariable("GODOT_EXECUTABLE"),
            BridgeUrl = "ws://127.0.0.1:8793", Headless = true,
            AdditionalArguments = args,
            EnvironmentVariables = new Dictionary<string, string> { ["APPDATA"] = Path.Combine(evidence, "appdata") }
        });
        var version = host.Context.GetVersion();
        Assert.That(version.CoreVersion, Is.EqualTo("1.1.2"));
        Assert.That(version.GodotPluginVersion, Is.EqualTo("1.1.2"));
        File.WriteAllText(Path.Combine(evidence, "version.json"), JsonSerializer.Serialize(version));
        GuaAssertions.WaitForId(host.Context, "start").ToBeVisible();
        GuaAssertions.WaitUntil(() => host.Context.GetContextStatus().FrameSequence >= 2,
            "initial guild observation published", TimeSpan.FromSeconds(3));
        expectedBugs = bug == null ? Array.Empty<string>() : new[] { bug };
        AssertBugMode();
    }
    void Close() { host?.Dispose(); host = null; }
    [SetUp] public void Setup()
    {
        evidence = Path.Combine(Root, "output", "source-regression", TestContext.CurrentContext.Test.ID + "-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(evidence);
        save = Path.Combine(evidence, "save.json");
        lastObserve = null;
    }
    [TearDown] public void Teardown()
    {
        try
        {
            if (host != null)
            {
                File.WriteAllText(Path.Combine(evidence, "final-ui.json"), host.Context.GetUiTreeJson());
                // Preserve the last actually asserted observation with its own
                // frame metadata; do not call it a fresh final snapshot.
                if (lastObserve != null) File.WriteAllText(Path.Combine(evidence, "last-observe.json"), lastObserve);
                if (TestContext.CurrentContext.Result.Outcome.Status == TestStatus.Failed)
                    host.CreateDiagnosticsSession(TestContext.CurrentContext.Test.Name, evidence)
                        .Capture(new AssertionException(TestContext.CurrentContext.Result.Message));
            }
        }
        finally { Close(); }
    }
    void Click(string id)
    {
        var completion = GuaAssertions.Query(host!.Context).ById(id).Click(
            timeout: TimeSpan.FromSeconds(5), pollInterval: TimeSpan.FromMilliseconds(100));
        // This game rebuilds controls in the callback. Completion precedes the
        // next published UI frame; wait for that frame before choosing again.
        GuaAssertions.WaitUntil(() => host!.Context.GetContextStatus().FrameSequence > completion.FrameSequence,
            "guild UI republished after callback", TimeSpan.FromSeconds(3));
        if (id is "start" or "reset" or "replay") AssertBugMode();
        TestContext.Progress.WriteLine($"UI click {id}");
    }
    void Clicks(params string[] ids) { foreach (var id in ids) Click(id); }
    string ReadObservations()
    {
        // The Godot host retains its operation connection. Observe uses the
        // official API in a bounded read scope, not a second idle client.
        using var observer = new GuaWebSocketContext("ws://127.0.0.1:8793");
        return lastObserve = observer.GetObserveSnapshotJson();
    }
    JsonNode Observe(string name)
    {
        var envelope = JsonNode.Parse(ReadObservations())!;
        var entries = envelope["document"]!["entries"]!.AsArray();
        var entry = entries.Single(e => e!["name"]!.GetValue<string>() == name)!;
        Assert.That(entry["status"]!.GetValue<string>(), Is.EqualTo("available"));
        return entry["value"]!["value"]!;
    }
    JsonNode State() => JsonNode.Parse(Observe("state").GetValue<string>())!;
    void AssertBugMode()
    {
        var actualBugs = State()["bugs"]!.AsArray().Select(value => value!.GetValue<string>()).ToArray();
        Assert.That(actualBugs, Is.EqualTo(expectedBugs), "normal and single-bug runs must not enable unrelated defects");
    }
    int Gold() => State()["gold"]!.AsInt();
    int Count(string item) => State()["bag"]?[item]?.AsInt() ?? 0;
    string Status(int i) => State()["quests"]![i]!["status"]!.GetValue<string>();
    void EconomyEqual(JsonNode before)
    {
        var after = State();
        foreach (var key in new[] { "gold", "bag", "stock" })
            Assert.That(JsonNode.DeepEquals(before[key], after[key]), Is.True, $"economic state {key} changed");
    }
    void Quantity(int count)
    {
        for (var i = 0; i < 10; i++) Click("qty_minus");
        for (var i = 1; i < count; i++) Click("qty_plus");
        GuaAssertions.GetByText(host!.Context, $"数量: {count}").ToBeVisible();
        var node = JsonNode.Parse(host.Context.GetUiTreeJson())!["nodes"]!.AsArray()
            .Single(n => n!["label"]?.GetValue<string>() == $"数量: {count}")!;
        Assert.That(node["bounds"]!["w"]!.GetValue<double>(), Is.GreaterThanOrEqualTo(150));
    }
    void Buy(string item, int count)
    {
        Click("select_" + item); Quantity(count); Clicks("buy", "confirm_trade");
    }
    void Talk() => Clicks("talk", "talk_supplies", "back");
    void CancelPurchaseConfirmation()
    {
        Click("buy");
        var tree = JsonNode.Parse(host!.Context.GetUiTreeJson())!;
        Assert.That(tree["screen"]!.GetValue<string>(), Is.EqualTo("confirmation"));
        Assert.That(tree["nodes"]!.AsArray().Any(node => node!["id"]!.GetValue<string>() == "back"),
            Is.False, "the confirmation must not publish the background back action");
        Click("cancel_trade");
    }
    void Deliver(int index, string item, int count)
    {
        Clicks("choose_item", "bag_" + item, "to_requests");
        for (var n = 0; n < count; n++) Click("deliver_" + index);
    }

    [Test] public void StartCompleteReplayAndSettings()
    {
        Open(); Click("start"); Talk(); Click("shop");
        Buy("herb", 3); Buy("rope", 2); Buy("crystal", 2);
        Assert.That(Gold(), Is.EqualTo(8));
        Clicks("back", "quests");
        for (var i = 0; i < 3; i++) Click("accept_" + i);
        var items = new[] { "herb", "rope", "crystal" }; var needs = new[] { 3, 2, 2 };
        for (var i = 0; i < 3; i++) { Deliver(i, items[i], needs[i]); Click("claim_" + i); }
        Assert.That(host!.RemoteContext.GetCurrentScreen(), Is.EqualTo("result"));
        Assert.That(Gold(), Is.EqualTo(82));
        Clicks("pause", "settings", "language", "size_880");
        GuaAssertions.GetByRole(host!.Context, "button", "Language: English → 日本語").ToBeVisible();
        Clicks("settings_back", "resume", "replay");
        Assert.That(Gold(), Is.EqualTo(60)); Assert.That(State()["day"]!.AsInt(), Is.EqualTo(1));
    }
    [Test] public void SavePartialAndClaimAcrossSourceProcesses()
    {
        Open(); Click("start"); Talk(); Click("shop"); Buy("herb", 3); Clicks("back", "quests", "accept_0");
        Deliver(0, "herb", 1); Clicks("back", "pause", "save"); Close();
        Open(); Clicks("load", "quests"); Assert.That(State()["quests"]![0]!["delivered"]!.AsInt(), Is.EqualTo(1));
        Assert.That(Count("herb"), Is.EqualTo(2)); Deliver(0, "herb", 2); Click("claim_0");
        Assert.That(Gold(), Is.EqualTo(68)); Clicks("back", "pause", "save"); Close();
        Open(); Clicks("load", "quests", "claim_0"); Assert.That(Gold(), Is.EqualTo(68)); Assert.That(Status(0), Is.EqualTo("done"));
    }
    [Test] public void EconomicBoundariesAndCancelledConfirmation()
    {
        Open(); Clicks("start", "shop"); var initial = State(); CancelPurchaseConfirmation(); EconomyEqual(initial);
        Buy("crystal", 6); EconomyEqual(initial); Assert.That(State()["history"]!.AsArray().Last()!["result"]!.GetValue<string>(), Is.EqualTo("gold_low"));
        Quantity(9); Click("qty_plus"); GuaAssertions.GetByText(host!.Context, "数量: 9").ToBeVisible();
        Clicks("buy", "confirm_trade"); EconomyEqual(initial);
        Buy("herb", 1); Buy("rope", 1); Buy("crystal", 1); var full = State(); Buy("map", 1); EconomyEqual(full);
        Clicks("back", "pause", "reset", "shop"); Buy("herb", 9); var stacked = State();
        Quantity(1); Click("qty_minus"); GuaAssertions.GetByText(host!.Context, "数量: 1").ToBeVisible();
        Clicks("buy", "confirm_trade"); EconomyEqual(stacked);
        Click("back"); for (var i = 0; i < 9; i++) Click("next_day");
        Click("shop"); Quantity(9); var stockFull = State(); Clicks("sell", "confirm_trade"); EconomyEqual(stockFull);
        Clicks("back", "pause", "save", "load"); EconomyEqual(stockFull);
    }
    [Test] public void SoldSuppliesRecoverAndDeadlinesAdvanceOnlyExplicitly()
    {
        Open(); Click("start");
        const string initialHeader = "日付 1  |  所持金 60 G  |  鞄 0 / 3 種（各9個）";
        GuaAssertions.GetByText(host!.Context, initialHeader).ToBeVisible(); Thread.Sleep(1200);
        GuaAssertions.GetByText(host.Context, initialHeader).ToBeVisible();
        Click("quests"); Click("accept_0"); Assert.That(Status(0), Is.EqualTo("open")); Click("back"); Talk();
        Click("shop"); Buy("herb", 3); Quantity(1); Clicks("sell", "confirm_trade", "back", "quests", "accept_0");
        Deliver(0, "herb", 2); var before = State(); Click("deliver_0"); EconomyEqual(before); Assert.That(Status(0), Is.EqualTo("active"));
        Clicks("back", "shop"); Buy("herb", 1); Clicks("back", "quests"); Deliver(0, "herb", 1); Click("claim_0");
        Clicks("accept_1", "back"); for (var i = 0; i < 5; i++) Click("next_day");
        Assert.That(Status(1), Is.EqualTo("expired")); before = State(); Clicks("quests", "claim_1"); EconomyEqual(before);
    }
    [Test] public void StockZeroSaleAndReacquisition()
    {
        Open(); Click("start"); Talk(); Click("shop"); Buy("herb", 9);
        Clicks("back", "quests", "accept_0"); Deliver(0, "herb", 3);
        Clicks("back", "shop"); Buy("herb", 3);
        Assert.That(State()["stock"]!["herb"]!.AsInt(), Is.Zero);
        Quantity(1); var emptyStock = State(); Clicks("buy", "confirm_trade"); EconomyEqual(emptyStock);
        Assert.That(State()["history"]!.AsArray().Last()!["result"]!.GetValue<string>(), Is.EqualTo("stock_low"));
        Clicks("sell", "confirm_trade"); Assert.That(State()["stock"]!["herb"]!.AsInt(), Is.EqualTo(1));
        Clicks("buy", "confirm_trade"); Assert.That(State()["stock"]!["herb"]!.AsInt(), Is.Zero);
        Assert.That(Count("herb"), Is.EqualTo(9));
    }
    [TestCase(null), TestCase("cancel_charge")]
    public void CancelBugComparison(string? bug)
    {
        Open(bug); Clicks("start", "shop"); CancelPurchaseConfirmation();
        Assert.That(Gold(), Is.EqualTo(bug == null ? 60 : 56), "independent normal cancellation expectation is 60G");
    }
    [TestCase(null), TestCase("double_reward")]
    public void RewardBugComparison(string? bug)
    {
        Open(bug); Click("start"); Talk(); Click("shop"); Buy("herb", 3);
        Clicks("back", "quests", "accept_0"); Deliver(0, "herb", 3); Clicks("claim_0", "claim_0");
        Assert.That(Gold(), Is.EqualTo(bug == null ? 68 : 88), "independent one-reward expectation is 68G");
    }
    [TestCase(null), TestCase("sort_target")]
    public void SortBugComparison(string? bug)
    {
        Open(bug); Clicks("start", "shop"); Buy("herb", 1); Buy("rope", 1);
        Clicks("back", "inventory", "bag_herb", "sort");
        Assert.That(Observe("selection").GetValue<string>(), Is.EqualTo(bug == null ? "herb" : "rope"));
    }
}

[TestFixture, Category("DistributionSmoke"), NonParallelizable, Explicit("Only scripts/smoke-exe.ps1 starts the packaged EXE for this limited smoke")]
public sealed class DistributionSmoke
{
    [Test] public void PackagedTitleAndOfficialVersionOnly()
    {
        using var context = new GuaWebSocketContext("ws://127.0.0.1:8793");
        context.WaitUntilAvailable(TimeSpan.FromSeconds(10));
        var version = context.GetVersion();
        Assert.That(version.CoreVersion, Is.EqualTo("1.1.2"));
        Assert.That(version.GodotPluginVersion, Is.EqualTo("1.1.2"));
        GuaAssertions.GetById(context, "start").ToBeVisible();
        GuaAssertions.GetById(context, "load").ToBeVisible();
        Assert.That(context.GetRemoteTree().Screen, Is.EqualTo("title"));
        TestContext.Progress.WriteLine("LIMITED EXE SMOKE: version/title only; no playthrough, scenario, trace or replay");
    }
}

[TestFixture, Category("SourceRegression"), NonParallelizable]
public sealed class SourceConnectionProbe
{
    [Test] public void OfficialHostOnlyNavigation()
    {
        var directory = new DirectoryInfo(TestContext.CurrentContext.TestDirectory);
        while (directory != null && !File.Exists(Path.Combine(directory.FullName, "project.godot"))) directory=directory.Parent;
        var root=directory?.FullName ?? throw new InvalidOperationException("project missing");
        using var host=GodotSceneTestHost.Load("res://main.tscn", new() {
            ProjectPath=root, GodotExecutablePath=Environment.GetEnvironmentVariable("GODOT_EXECUTABLE"),
            BridgeUrl="ws://127.0.0.1:8793", Headless=true,
            EnvironmentVariables=new Dictionary<string,string> { ["APPDATA"]=Path.Combine(root,"output","source-probe-appdata") }
        });
        foreach(var id in new[]{"start","shop","buy","cancel_trade"})
            GuaAssertions.Query(host.Context).ById(id).Click(timeout:TimeSpan.FromSeconds(5),pollInterval:TimeSpan.FromMilliseconds(100));
        Assert.That(host.RemoteContext.GetCurrentScreen(),Is.EqualTo("shop"));
    }
}

static class JsonGameInteger
{
    public static int AsInt(this JsonNode node)
    {
        var value = node.GetValue<double>();
        Assert.That(double.IsFinite(value) && value == Math.Truncate(value), Is.True, "game count must be an integer");
        return checked((int)value);
    }
}
