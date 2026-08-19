#Requires -Version 5.1

<#
.SYNOPSIS
Print keyboard combinations observed on the current Windows desktop.

.DESCRIPTION
Install a temporary low-level Windows keyboard hook and print one normalized
combination per non-modifier key-down event. The PowerShell console does not
need to have focus, so registered shortcuts such as Win+Shift+C can be observed
without preventing the owning application from handling them.

Events that Windows marks as injected are included and labeled. This metadata
can help diagnose remote-control and AutoHotkey behavior, but it does not prove
which device or program originated an event. Use -Verbose to see every key-down
and key-up event with its virtual key, scan code, flags, timestamp, and
extra-info value.

When this terminal has focus, its console input is discarded while monitoring.
Consequently, Ctrl+V is logged as a key combination without leaving clipboard
text to execute at the prompt afterward. Press Esc once or Ctrl+C twice
consecutively to stop. Exit keypresses are printed before the monitor stops.

Secure-desktop input such as Ctrl+Alt+Delete cannot be observed.

.EXAMPLE
keyPressMonitor

.EXAMPLE
keyPressMonitor -Verbose
#>
[CmdletBinding()]
param()

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
  Write-Error 'keyPressMonitor requires Windows.'
  return
}

if ([Console]::IsInputRedirected) {
  Write-Error 'keyPressMonitor requires an interactive console; standard input is redirected.'
  return
}

$rawUI = $Host.UI.RawUI
if ($null -eq $rawUI) {
  Write-Error 'keyPressMonitor requires an interactive console host.'
  return
}

$hookType = 'Dotfiles.KeyPressMonitor.V2.GlobalKeyboardHook' -as [type]
if ($null -eq $hookType) {
  $hookSource = @'
using System;
using System.Collections.Concurrent;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Threading;

namespace Dotfiles.KeyPressMonitor.V2
{
  public sealed class KeyboardEvent
  {
      public int RawVirtualKeyCode { get; private set; }
      public int VirtualKeyCode { get; private set; }
      public int ScanCode { get; private set; }
      public bool KeyDown { get; private set; }
      public bool EffectiveKeyDown { get; private set; }
      public bool Repeat { get; private set; }
      public bool Control { get; private set; }
      public bool Alt { get; private set; }
      public bool Shift { get; private set; }
      public bool Windows { get; private set; }
      public bool Injected { get; private set; }
      public bool LowerIntegrityInjected { get; private set; }
      public uint Flags { get; private set; }
      public uint Time { get; private set; }
      public ulong ExtraInfo { get; private set; }

      internal KeyboardEvent(
          int rawVirtualKeyCode,
          int virtualKeyCode,
          int scanCode,
          bool keyDown,
          bool effectiveKeyDown,
          bool repeat,
          bool control,
          bool alt,
          bool shift,
          bool windows,
          bool injected,
          bool lowerIntegrityInjected,
          uint flags,
          uint time,
          ulong extraInfo)
      {
          RawVirtualKeyCode = rawVirtualKeyCode;
          VirtualKeyCode = virtualKeyCode;
          ScanCode = scanCode;
          KeyDown = keyDown;
          EffectiveKeyDown = effectiveKeyDown;
          Repeat = repeat;
          Control = control;
          Alt = alt;
          Shift = shift;
          Windows = windows;
          Injected = injected;
          LowerIntegrityInjected = lowerIntegrityInjected;
          Flags = flags;
          Time = time;
          ExtraInfo = extraInfo;
      }
  }

  public static class GlobalKeyboardHook
  {
      private const int WH_KEYBOARD_LL = 13;
      private const int WM_KEYDOWN = 0x0100;
      private const int WM_KEYUP = 0x0101;
      private const int WM_SYSKEYDOWN = 0x0104;
      private const int WM_SYSKEYUP = 0x0105;
      private const uint WM_QUIT = 0x0012;
      private const uint PM_NOREMOVE = 0x0000;
      private const uint LLKHF_EXTENDED = 0x00000001;
      private const uint LLKHF_LOWER_IL_INJECTED = 0x00000002;
      private const uint LLKHF_INJECTED = 0x00000010;
      private const uint MAPVK_VSC_TO_VK_EX = 3;

      private const int VK_SHIFT = 0x10;
      private const int VK_CONTROL = 0x11;
      private const int VK_MENU = 0x12;
      private const int VK_LWIN = 0x5B;
      private const int VK_RWIN = 0x5C;
      private const int VK_LSHIFT = 0xA0;
      private const int VK_RSHIFT = 0xA1;
      private const int VK_LCONTROL = 0xA2;
      private const int VK_RCONTROL = 0xA3;
      private const int VK_LMENU = 0xA4;
      private const int VK_RMENU = 0xA5;

      [StructLayout(LayoutKind.Sequential)]
      private struct KbdLlHookStruct
      {
          public uint VirtualKeyCode;
          public uint ScanCode;
          public uint Flags;
          public uint Time;
          public UIntPtr ExtraInfo;
      }

      [StructLayout(LayoutKind.Sequential)]
      private struct Point
      {
          public int X;
          public int Y;
      }

      [StructLayout(LayoutKind.Sequential)]
      private struct Message
      {
          public IntPtr Window;
          public uint Id;
          public UIntPtr WParam;
          public IntPtr LParam;
          public uint Time;
          public Point Cursor;
          public uint Private;
      }

      [UnmanagedFunctionPointer(CallingConvention.Winapi)]
      private delegate IntPtr LowLevelKeyboardProcedure(int code, IntPtr wParam, IntPtr lParam);

      [DllImport("user32.dll", EntryPoint = "SetWindowsHookExW", SetLastError = true)]
      private static extern IntPtr SetWindowsHookEx(
          int hookType,
          LowLevelKeyboardProcedure callback,
          IntPtr module,
          uint threadId);

      [DllImport("user32.dll", SetLastError = true)]
      [return: MarshalAs(UnmanagedType.Bool)]
      private static extern bool UnhookWindowsHookEx(IntPtr hook);

      [DllImport("user32.dll")]
      private static extern IntPtr CallNextHookEx(
          IntPtr hook,
          int code,
          IntPtr wParam,
          IntPtr lParam);

      [DllImport("user32.dll", SetLastError = true)]
      [return: MarshalAs(UnmanagedType.Bool)]
      private static extern bool PostThreadMessage(
          uint threadId,
          uint message,
          UIntPtr wParam,
          IntPtr lParam);

      [DllImport("user32.dll")]
      [return: MarshalAs(UnmanagedType.Bool)]
      private static extern bool PeekMessage(
          out Message message,
          IntPtr window,
          uint minimumMessage,
          uint maximumMessage,
          uint removeMessage);

      [DllImport("user32.dll", SetLastError = true)]
      private static extern int GetMessage(
          out Message message,
          IntPtr window,
          uint minimumMessage,
          uint maximumMessage);

      [DllImport("user32.dll")]
      [return: MarshalAs(UnmanagedType.Bool)]
      private static extern bool TranslateMessage(ref Message message);

      [DllImport("user32.dll")]
      private static extern IntPtr DispatchMessage(ref Message message);

      [DllImport("user32.dll")]
      private static extern short GetAsyncKeyState(int virtualKeyCode);

      [DllImport("user32.dll")]
      private static extern uint MapVirtualKey(uint code, uint mapType);

      [DllImport("kernel32.dll", EntryPoint = "GetModuleHandleW", CharSet = CharSet.Unicode)]
      private static extern IntPtr GetModuleHandle(string moduleName);

      [DllImport("kernel32.dll")]
      private static extern uint GetCurrentThreadId();

      private static readonly object SyncRoot = new object();
      private static readonly ConcurrentQueue<KeyboardEvent> EventQueue =
          new ConcurrentQueue<KeyboardEvent>();
      private static readonly AutoResetEvent EventAvailable = new AutoResetEvent(false);
      private static readonly ManualResetEventSlim StartupComplete =
          new ManualResetEventSlim(false);
      private static readonly LowLevelKeyboardProcedure HookProcedure = HookCallback;
      private static readonly bool[] UnmarkedKeyDownState = new bool[256];
      private static readonly bool[] InjectedKeyDownState = new bool[256];

      private static Thread _hookThread;
      private static uint _hookThreadId;
      private static IntPtr _hookHandle = IntPtr.Zero;
      private static Exception _startupException;
      private static string _lastError;
      private static string _cleanupError;
      private static volatile bool _stopRequested;

      public static bool IsRunning
      {
          get
          {
              lock (SyncRoot)
              {
                  return _hookHandle != IntPtr.Zero &&
                      _hookThread != null &&
                      _hookThread.IsAlive;
              }
          }
      }

      public static string LastError
      {
          get
          {
              lock (SyncRoot)
              {
                  return _lastError;
              }
          }
      }

      public static void Start()
      {
          lock (SyncRoot)
          {
              if (_hookThread != null && _hookThread.IsAlive)
              {
                  throw new InvalidOperationException("The global keyboard hook is already running.");
              }

              KeyboardEvent pendingEvent;
              while (EventQueue.TryDequeue(out pendingEvent))
              {
              }

              EventAvailable.Reset();
              StartupComplete.Reset();
              _startupException = null;
              _lastError = null;
              _cleanupError = null;
              _hookThreadId = 0;
              _hookHandle = IntPtr.Zero;
              _stopRequested = false;

              _hookThread = new Thread(HookThreadMain);
              _hookThread.IsBackground = true;
              _hookThread.Name = "Dotfiles keyboard monitor hook";
              _hookThread.Start();
          }

          if (!StartupComplete.Wait(5000))
          {
              try
              {
                  Stop();
              }
              catch
              {
              }
              throw new TimeoutException("Timed out while starting the global keyboard hook.");
          }

          Exception startupException;
          lock (SyncRoot)
          {
              startupException = _startupException;
          }

          if (startupException != null)
          {
              try
              {
                  Stop();
              }
              catch
              {
              }
              throw new InvalidOperationException(
                  "Unable to start the global keyboard hook.",
                  startupException);
          }
      }

      public static KeyboardEvent Dequeue()
      {
          KeyboardEvent keyboardEvent;
          return EventQueue.TryDequeue(out keyboardEvent) ? keyboardEvent : null;
      }

      public static bool WaitForEvent(int millisecondsTimeout)
      {
          return EventAvailable.WaitOne(millisecondsTimeout);
      }

      public static void Stop()
      {
          Thread hookThread;
          uint hookThreadId;

          lock (SyncRoot)
          {
              _stopRequested = true;
              hookThread = _hookThread;
              hookThreadId = _hookThreadId;
          }

          if (hookThread == null)
          {
              return;
          }

          if (hookThreadId != 0)
          {
              PostThreadMessage(hookThreadId, WM_QUIT, UIntPtr.Zero, IntPtr.Zero);
          }

          if (Thread.CurrentThread != hookThread && !hookThread.Join(5000))
          {
              IntPtr hookToRemove;
              lock (SyncRoot)
              {
                  hookToRemove = _hookHandle;
                  _hookHandle = IntPtr.Zero;
              }

              if (hookToRemove != IntPtr.Zero)
              {
                  if (!UnhookWindowsHookEx(hookToRemove))
                  {
                      RecordCleanupError(
                          "Unable to remove the global keyboard hook: " +
                          new Win32Exception(Marshal.GetLastWin32Error()).Message);
                  }
              }

              if (hookThreadId != 0)
              {
                  PostThreadMessage(hookThreadId, WM_QUIT, UIntPtr.Zero, IntPtr.Zero);
              }
              if (!hookThread.Join(1000))
              {
                  RecordCleanupError(
                      "The global keyboard hook thread did not stop within the timeout.");
              }
          }

          string cleanupError;
          lock (SyncRoot)
          {
              if (_hookThread == hookThread && !hookThread.IsAlive)
              {
                  _hookThread = null;
                  _hookThreadId = 0;
              }
              cleanupError = _cleanupError;
          }

          if (!String.IsNullOrEmpty(cleanupError))
          {
              throw new InvalidOperationException(cleanupError);
          }
      }

      private static void HookThreadMain()
      {
          try
          {
              _hookThreadId = GetCurrentThreadId();

              Message message;
              PeekMessage(out message, IntPtr.Zero, 0, 0, PM_NOREMOVE);
              InitializeKeyState();

              if (_stopRequested)
              {
                  StartupComplete.Set();
                  return;
              }

              IntPtr hook = SetWindowsHookEx(
                  WH_KEYBOARD_LL,
                  HookProcedure,
                  GetModuleHandle(null),
                  0);

              if (hook == IntPtr.Zero)
              {
                  throw new Win32Exception(Marshal.GetLastWin32Error());
              }

              lock (SyncRoot)
              {
                  _hookHandle = hook;
              }

              StartupComplete.Set();

              int messageResult = 0;
              while (!_stopRequested &&
                  (messageResult = GetMessage(out message, IntPtr.Zero, 0, 0)) > 0)
              {
                  TranslateMessage(ref message);
                  DispatchMessage(ref message);
              }

              if (!_stopRequested && messageResult == -1)
              {
                  throw new Win32Exception(Marshal.GetLastWin32Error());
              }
          }
          catch (Exception exception)
          {
              lock (SyncRoot)
              {
                  if (!StartupComplete.IsSet)
                  {
                      _startupException = exception;
                  }
                  _lastError = exception.Message;
              }
          }
          finally
          {
              IntPtr hookToRemove;
              lock (SyncRoot)
              {
                  hookToRemove = _hookHandle;
                  _hookHandle = IntPtr.Zero;
              }

              if (hookToRemove != IntPtr.Zero)
              {
                  if (!UnhookWindowsHookEx(hookToRemove))
                  {
                      RecordCleanupError(
                          "Unable to remove the global keyboard hook: " +
                          new Win32Exception(Marshal.GetLastWin32Error()).Message);
                  }
              }

              if (!StartupComplete.IsSet)
              {
                  StartupComplete.Set();
              }
              EventAvailable.Set();
          }
      }

      private static void InitializeKeyState()
      {
          Array.Clear(UnmarkedKeyDownState, 0, UnmarkedKeyDownState.Length);
          Array.Clear(InjectedKeyDownState, 0, InjectedKeyDownState.Length);

          int[] modifierKeys = new int[]
          {
              VK_LWIN,
              VK_RWIN,
              VK_LSHIFT,
              VK_RSHIFT,
              VK_LCONTROL,
              VK_RCONTROL,
              VK_LMENU,
              VK_RMENU
          };

          foreach (int key in modifierKeys)
          {
              UnmarkedKeyDownState[key] = (GetAsyncKeyState(key) & 0x8000) != 0;
          }
      }

      private static IntPtr HookCallback(int code, IntPtr wParam, IntPtr lParam)
      {
          try
          {
              int message = unchecked((int)(long)wParam);
              bool keyDown = message == WM_KEYDOWN || message == WM_SYSKEYDOWN;
              bool keyUp = message == WM_KEYUP || message == WM_SYSKEYUP;

              if (code >= 0 && (keyDown || keyUp))
              {
                  KbdLlHookStruct data =
                      (KbdLlHookStruct)Marshal.PtrToStructure(lParam, typeof(KbdLlHookStruct));
                  int keyCode = NormalizeModifierVirtualKey(data);
                  bool injected = (data.Flags & LLKHF_INJECTED) != 0;
                  bool lowerIntegrityInjected =
                      (data.Flags & LLKHF_LOWER_IL_INJECTED) != 0;
                  bool[] sourceKeyDownState =
                      injected ? InjectedKeyDownState : UnmarkedKeyDownState;
                  bool repeat = false;

                  if (keyCode >= 0 && keyCode < sourceKeyDownState.Length)
                  {
                      repeat = keyDown && IsKeyDown(keyCode);
                      sourceKeyDownState[keyCode] = keyDown;
                  }
                  bool effectiveKeyDown = IsKeyDown(keyCode);

                  bool control = IsKeyDown(VK_CONTROL) ||
                      IsKeyDown(VK_LCONTROL) || IsKeyDown(VK_RCONTROL);
                  bool alt = IsKeyDown(VK_MENU) ||
                      IsKeyDown(VK_LMENU) || IsKeyDown(VK_RMENU);
                  bool shift = IsKeyDown(VK_SHIFT) ||
                      IsKeyDown(VK_LSHIFT) || IsKeyDown(VK_RSHIFT);
                  bool windows = IsKeyDown(VK_LWIN) || IsKeyDown(VK_RWIN);

                  EventQueue.Enqueue(new KeyboardEvent(
                      unchecked((int)data.VirtualKeyCode),
                      keyCode,
                      unchecked((int)data.ScanCode),
                      keyDown,
                      effectiveKeyDown,
                      repeat,
                      control,
                      alt,
                      shift,
                      windows,
                      injected,
                      lowerIntegrityInjected,
                      data.Flags,
                      data.Time,
                      data.ExtraInfo.ToUInt64()));
                  EventAvailable.Set();
              }
          }
          catch (Exception exception)
          {
              lock (SyncRoot)
              {
                  _lastError = "Keyboard hook callback failed: " + exception.Message;
              }
              EventAvailable.Set();
              PostThreadMessage(_hookThreadId, WM_QUIT, UIntPtr.Zero, IntPtr.Zero);
          }

          return CallNextHookEx(IntPtr.Zero, code, wParam, lParam);
      }

      private static int NormalizeModifierVirtualKey(KbdLlHookStruct data)
      {
          int keyCode = unchecked((int)data.VirtualKeyCode);

          if (keyCode == VK_SHIFT)
          {
              uint mappedKey = MapVirtualKey(data.ScanCode, MAPVK_VSC_TO_VK_EX);
              return mappedKey == 0 ? keyCode : unchecked((int)mappedKey);
          }
          if (keyCode == VK_CONTROL)
          {
              return (data.Flags & LLKHF_EXTENDED) != 0 ? VK_RCONTROL : VK_LCONTROL;
          }
          if (keyCode == VK_MENU)
          {
              return (data.Flags & LLKHF_EXTENDED) != 0 ? VK_RMENU : VK_LMENU;
          }

          return keyCode;
      }

      private static bool IsKeyDown(int keyCode)
      {
          if (keyCode < 0 || keyCode >= UnmarkedKeyDownState.Length)
          {
              return false;
          }
          return UnmarkedKeyDownState[keyCode] || InjectedKeyDownState[keyCode];
      }

      private static void RecordCleanupError(string message)
      {
          lock (SyncRoot)
          {
              if (String.IsNullOrEmpty(_cleanupError))
              {
                  _cleanupError = message;
              }
              else
              {
                  _cleanupError = _cleanupError + " " + message;
              }
          }
      }
  }
}
'@

  try {
    $null = Add-Type -TypeDefinition $hookSource -Language CSharp -ErrorAction Stop
    $hookType = 'Dotfiles.KeyPressMonitor.V2.GlobalKeyboardHook' -as [type]
  }
  catch {
    Write-Error "keyPressMonitor could not initialize its Windows keyboard hook: $($_.Exception.Message)"
    return
  }
}

$modifierVirtualKeyCodes = @(
  0x10, 0x11, 0x12,
  0x5B, 0x5C,
  0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5
)
$modifierVirtualKeyNames = @{
  0x10 = 'Shift'
  0x11 = 'Ctrl'
  0x12 = 'Alt'
  0x5B = 'LWin'
  0x5C = 'RWin'
  0xA0 = 'LShift'
  0xA1 = 'RShift'
  0xA2 = 'LCtrl'
  0xA3 = 'RCtrl'
  0xA4 = 'LAlt'
  0xA5 = 'RAlt'
}
$previousWasCtrlC = $false
$waitingForSecondCtrlCRelease = $false
$originalTreatControlCAsInput = $false
$shouldRestoreControlCHandling = $false
$hookStarted = $false

function Get-KeyPressMonitorKeyName {
  param([int]$KeyCode)

  if ($modifierVirtualKeyNames.ContainsKey($KeyCode)) {
    return $modifierVirtualKeyNames[$KeyCode]
  }

  $keyName = [Enum]::GetName([ConsoleKey], $KeyCode)
  if ($keyName -match '^D([0-9])$') {
    return $Matches[1]
  }
  if ($keyName -eq 'Escape') {
    return 'Esc'
  }
  if ($keyName -eq 'Spacebar') {
    return 'Space'
  }
  if ([string]::IsNullOrEmpty($keyName)) {
    return 'VK_0x{0:X2}' -f $KeyCode
  }
  return $keyName
}

function Get-KeyPressMonitorChord {
  param($KeyboardEvent)

  $parts = @()
  if ($KeyboardEvent.Windows) {
    $parts += 'Win'
  }
  if ($KeyboardEvent.Control) {
    $parts += 'Ctrl'
  }
  if ($KeyboardEvent.Alt) {
    $parts += 'Alt'
  }
  if ($KeyboardEvent.Shift) {
    $parts += 'Shift'
  }

  $keyCode = [int]$KeyboardEvent.VirtualKeyCode
  if ($modifierVirtualKeyCodes -notcontains $keyCode) {
    $parts += Get-KeyPressMonitorKeyName $keyCode
  }

  if ($parts.Count -eq 0) {
    return '(none)'
  }
  return $parts -join '+'
}

function Get-KeyPressMonitorEventKind {
  param($KeyboardEvent)

  if ($KeyboardEvent.LowerIntegrityInjected) {
    return 'Injected-LowerIL'
  }
  if ($KeyboardEvent.Injected) {
    return 'Injected'
  }
  return 'Unmarked'
}

function Clear-KeyPressMonitorConsoleInput {
  param([switch]$WaitForQuiet)

  if (-not $WaitForQuiet) {
    if ($rawUI.KeyAvailable) {
      $rawUI.FlushInputBuffer()
    }
    return
  }

  $deadline = [Diagnostics.Stopwatch]::StartNew()
  $quietTime = [Diagnostics.Stopwatch]::StartNew()

  while (($deadline.ElapsedMilliseconds -lt 3000) -and
         ($quietTime.ElapsedMilliseconds -lt 150)) {
    if ($rawUI.KeyAvailable) {
      $rawUI.FlushInputBuffer()
      $quietTime.Restart()
    } else {
      Start-Sleep -Milliseconds 10
    }
  }

  if ($rawUI.KeyAvailable) {
    $rawUI.FlushInputBuffer()
  }
}

try {
  try {
    $originalTreatControlCAsInput = [Console]::TreatControlCAsInput
    [Console]::TreatControlCAsInput = $true
    $shouldRestoreControlCHandling = $true
  }
  catch {
    throw "The console could not enable Ctrl+C key capture: $($_.Exception.Message)"
  }

  Clear-KeyPressMonitorConsoleInput

  $hookType::Start()
  $hookStarted = $true

  Write-Host 'Monitoring keyboard input on the current desktop. Press Esc or Ctrl+C twice to stop.' -ForegroundColor DarkGray

  while ($true) {
    $keyboardEvent = $hookType::Dequeue()
    if ($null -eq $keyboardEvent) {
      $null = $hookType::WaitForEvent(25)
      Clear-KeyPressMonitorConsoleInput

      if (-not $hookType::IsRunning) {
        $hookError = $hookType::LastError
        if ([string]::IsNullOrEmpty($hookError)) {
          $hookError = 'The keyboard hook stopped unexpectedly.'
        }
        throw $hookError
      }
      continue
    }

    Clear-KeyPressMonitorConsoleInput
    $keyCode = [int]$keyboardEvent.VirtualKeyCode
    $rawKeyCode = [int]$keyboardEvent.RawVirtualKeyCode
    $keyName = Get-KeyPressMonitorKeyName $keyCode
    $chord = Get-KeyPressMonitorChord $keyboardEvent
    $eventKind = Get-KeyPressMonitorEventKind $keyboardEvent
    $direction = if ($keyboardEvent.KeyDown) { 'down' } else { 'up' }
    Write-Verbose ('{0} key={1} chord={2} event={3} repeat={4} vk=0x{5:X2} normalizedVk=0x{6:X2} sc=0x{7:X2} flags=0x{8:X2} time={9} extra=0x{10:X16}' -f
      $direction,
      $keyName,
      $chord,
      $eventKind,
      $keyboardEvent.Repeat,
      $rawKeyCode,
      $keyCode,
      [int]$keyboardEvent.ScanCode,
      [uint32]$keyboardEvent.Flags,
      [uint32]$keyboardEvent.Time,
      [uint64]$keyboardEvent.ExtraInfo)

    $eventLine = '{0} [event={1}]' -f $chord, $eventKind

    if ($waitingForSecondCtrlCRelease) {
      if ($keyboardEvent.KeyDown -and
          ($keyCode -eq [int][ConsoleKey]::Escape)) {
        Write-Output $eventLine
        break
      }
      if ((-not $keyboardEvent.KeyDown) -and
          ($keyCode -eq [int][ConsoleKey]::C) -and
          (-not $keyboardEvent.EffectiveKeyDown)) {
        break
      }
      continue
    }

    if (-not $keyboardEvent.KeyDown) {
      continue
    }

    if ($modifierVirtualKeyCodes -contains $keyCode) {
      continue
    }

    $isCtrlC = $keyboardEvent.Control -and
               -not $keyboardEvent.Alt -and
               -not $keyboardEvent.Shift -and
               -not $keyboardEvent.Windows -and
               ($keyCode -eq [int][ConsoleKey]::C)

    # Do not treat auto-repeat from one held Ctrl+C as a second keypress.
    if ($isCtrlC -and $keyboardEvent.Repeat) {
      continue
    }

    Write-Output $eventLine

    if ($keyCode -eq [int][ConsoleKey]::Escape) {
      break
    }
    if ($isCtrlC -and $previousWasCtrlC) {
      $waitingForSecondCtrlCRelease = $true
      continue
    }
    $previousWasCtrlC = $isCtrlC
  }
}
catch {
  Write-Error "keyPressMonitor stopped: $($_.Exception.Message)"
}
finally {
  if ($hookStarted) {
    try {
      $hookType::Stop()
    }
    catch {
      Write-Warning "keyPressMonitor could not cleanly stop its keyboard hook: $($_.Exception.Message)"
    }
  }

  try {
    Clear-KeyPressMonitorConsoleInput -WaitForQuiet
  }
  catch {
    Write-Warning "keyPressMonitor could not finish draining console input: $($_.Exception.Message)"
  }

  if ($shouldRestoreControlCHandling) {
    try {
      [Console]::TreatControlCAsInput = $originalTreatControlCAsInput
    }
    catch {
      Write-Warning "keyPressMonitor could not restore Ctrl+C console handling: $($_.Exception.Message)"
    }
  }
}
