# TwichUI Profiler Guide

A comprehensive profiling system for identifying performance bottlenecks in TwichUI Redux.

## Quick Start

### Basic Commands

```
/tui profile start      - Start profiling
/tui profile stop       - Stop profiling
/tui profile report     - Open visual results window (charts & metrics)
/tui profile window     - Same as report
/tui profile export     - Export data to chat (copy-paste to a file)
/tui profile clear      - Clear all profiling data
/tui profile status     - Show available commands
```

## Visual Window

When you run `/tui profile report`, a dedicated window opens showing:

- **Function Name**: The profiled function (clickable tooltip for full path)
- **Calls**: Number of times executed
- **Total (ms)**: Cumulative execution time (displayed on visual bar)
- **Avg (ms)**: Average per execution
- **Max (ms)**: Slowest single execution (color-coded)
- **Visual Bar**: Proportional bar chart showing worst offenders

### Color Coding

- 🟢 **Green** — Good performance (< 0.5 ms)
- 🟡 **Yellow** — Moderate (0.5 - 2 ms)
- 🔴 **Red** — Slow (> 2 ms) — needs optimization

### Sorting

Click any column header to sort by that metric:

- Function Name
- Call count
- Total time
- Average time
- Max time

Click again to reverse sort order.

## Usage Scenarios

### Scenario 1: Find Expensive Functions During Gameplay

1. Start profiling:

   ```
   /tui profile start
   ```

2. Play normally for a while (run dungeons, raids, do quests, etc.)

3. Stop profiling:

   ```
   /tui profile stop
   ```

4. View the report in the visual window:
   ```
   /tui profile report
   ```

The window displays:

- **Function Name**: What was profiled (hover for full path)
- **Calls**: How many times it was called
- **Total (ms)**: Total time spent (bar chart shows relative impact)
- **Avg (ms)**: Average time per call (click to sort)
- **Max (ms)**: Slowest single execution (color: green/yellow/red)
- **Visual Bar**: Proportional comparison of worst offenders

### Features

- **Sortable Columns**: Click any header to sort ascending/descending
- **Color Coding**: Red = critical (>2ms), Yellow = moderate (0.5-2ms), Green = good (<0.5ms)
- **Live Status**: Shows "RECORDING" or "STOPPED" in header
- **Movable Window**: Drag the title bar to reposition
- **Tooltip Details**: Hover over entries for min/max/avg breakdown

### Scenario 2: Export Data for Detailed Analysis

When you have profiling data that shows a potential issue:

```
/tui profile export
```

This outputs Lua-formatted data you can:

- Copy into a file for later analysis
- Share with me for optimization recommendations
- Use in external analysis tools
- Store for comparison between runs

## Understanding the Metrics

| Metric         | What It Means                 | Warning Signs                                        |
| -------------- | ----------------------------- | ---------------------------------------------------- |
| **Total (ms)** | Cumulative time for all calls | High = function is called frequently OR is expensive |
| **Calls**      | Number of times executed      | High = called very often (may need caching)          |
| **Avg (ms)**   | Average time per execution    | High = single call is expensive                      |
| **Max (ms)**   | Longest single execution      | High = creates lag spikes                            |

## Visual Window Guide

The profiler window displays all data in an interactive table with the following capabilities:

### Column Headers (Clickable to Sort)

Each column header is clickable to sort by that metric. Click again to reverse the sort order:

- **Function Name** — Full module:function path (hover for detailed tooltip)
- **Calls** — Total invocations during profiling session
- **Total (ms)** — Cumulative time (shown as visual bar)
- **Avg (ms)** — Average time per call (decimal precision)
- **Max (ms)** — Worst single execution (color-coded by severity)

### Color Severity Indicators

The **Max (ms)** column is color-coded to highlight performance issues:

- 🟢 **Green** — Excellent (< 0.5 ms per call) — no action needed
- 🟡 **Yellow/Orange** — Moderate (0.5 - 2 ms per call) — monitor
- 🔴 **Red** — Critical (> 2 ms per call) — optimize

### Visual Bar Chart

The rightmost column shows a proportional bar for each function's **total time**:

- Bar length represents the percentage of peak total time
- Longer bars = greater cumulative impact
- Find the longest bars first for maximum optimization gain

### Window Controls

- **Refresh** — Re-read profiler data from current session
- **Close** — Hide the window
- **Drag Title Bar** — Move window around screen
- **Hover Entries** — Shows detailed tooltip with min/avg/max/calls breakdown

### Status Indicator

The header shows the profiling status:

- **◌ RECORDING** (green) — Currently profiling
- **STOPPED** (red) — Profiling complete, no new data being collected

## Programmatic Usage

You can also profile functions in your code:

### Using Scopes

```lua
local Profiler = T.Tools.UI.Profiler

-- Profile a code block
local scope = Profiler:BeginScope("MyFunctionName")
-- ... do expensive work ...
Profiler:EndScope(scope)
```

### Wrapping Functions

```lua
local Profiler = T.Tools.UI.Profiler

-- Wrap a function for automatic profiling
local originalFunc = myModule.OnUpdate
myModule.OnUpdate = Profiler:ProfileFunction("MyModule:OnUpdate", originalFunc)
```

### Register entire modules

```lua
local Profiler = T.Tools.UI.Profiler

-- Profile specific functions in a module
Profiler:RegisterModuleForProfiling("MyModule", myModule, {
    "OnUpdate",
    "OnEvent",
    "RefreshUI"
})
```

## API Reference

### Profiler:StartProfiling()

Begins a profiling session. Resets collected data.

### Profiler:StopProfiling()

Ends the current profiling session.

### Profiler:GenerateReport()

Returns a formatted string report of profiling data.

### Profiler:ExportData()

Returns Lua-formatted profiling data (best for sharing).

### Profiler:GetProfileData()

Returns profiling data as a Lua table (for programmatic use).

### Profiler:ClearProfiles()

Clears all collected profiling data.

### Profiler:IsActive()

Returns `true` if profiling is currently active.

### Profiler:BeginScope(name)

Manually begin profiling a named code block.

- **name** (string): Name for this profiling scope
- **Returns**: ProfilingScope object

### Profiler:EndScope(scope)

Manually end a profiling scope.

- **scope** (ProfilingScope): The scope object from BeginScope

### Profiler:ProfileFunction(name, func)

Wrap a function with profiling.

- **name** (string): Name for this function
- **func** (function): The function to wrap
- **Returns**: Wrapped function

### Profiler:RegisterModuleForProfiling(name, tbl, functionNames)

Register a module for automatic profiling.

- **name** (string): Module name prefix
- **tbl** (table): The module/table containing functions
- **functionNames** (table, optional): List of function names to profile (profiles all if empty)

## Performance Impact

The profiler has minimal overhead:

- Profiling only runs when explicitly started
- Each scope entry/exit uses `debugprofilestop()` (WoW's built-in profiler)
- Profiling data is stored in memory (cleared when profiling is stopped)

**Note**: Profiling WILL impact frame rate while active. Use it for diagnostic purposes, not during critical gameplay.

## Sharing Profiling Results

When you have data to share for optimization:

1. Profile during typical gameplay
2. Export the data: `/tui profile export`
3. Copy the output to a text file
4. Share the file with me or attach to bug reports

This helps identify:

- Bottlenecks in specific modules
- Memory leaks (increasing memory usage in repeated calls)
- Functions called too frequently
- Single expensive operations

## Tips for Best Results

1. **Profile during relevant scenarios**: Profile during raid combat, not idle in Orgrimmar
2. **Long sessions**: Longer profiling periods give better statistical data
3. **Clear between tests**: Use `/tui profile clear` when testing specific features
4. **Multiple exports**: Get several exports under different conditions
5. **Note the context**: When exporting, note what you were doing (e.g., "M+ dungeon with 4 other players")

## Common Findings and Solutions

### Issue: OnUpdate called 1000+ times/second taking 5ms each

**Solution**: Consider using events instead of frame scripts, or throttle updates

### Issue: One function called once per frame at 12ms

**Solution**: This is a frame-time killer. Look for alternatives or cache results

### Issue: Memory growing during a single 20-minute dungeon run

**Solution**: Possible memory leak. Check for table accumulation without cleanup

### Issue: Function called differently in different scenarios

**Solution**: Use multiple profiles under different conditions to understand variance
