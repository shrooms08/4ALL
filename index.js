// Configuration and API Key

const VORLD_APP_ID = ""
let ARENA_GAME_ID = ""

// WebSocket connection
let socket = null;
let isWebSocketConnected = false;
let lastWebSocketUrl = null; // track which URL we attempted to connect to

// SHA-256 hash function
async function sha256(message) {
  // Encode as (utf-8) Uint8Array
  const msgBuffer = new TextEncoder().encode(message);

  // Hash the message
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgBuffer);

  // Convert ArrayBuffer to hex string
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return hashHex;
}

// DOM Elements
const baseUrlInput = document.getElementById("baseUrl");
const authUrlInput = document.getElementById("authUrl");
const emailInput = document.getElementById("email");
const passwordInput = document.getElementById("password");
const arenaGameIdInput = document.getElementById("arenaGameId");
const saveConfigBtn = document.getElementById("saveConfig");
const loginBtn = document.getElementById("loginBtn");
const streamerUrlInput = document.getElementById("streamerUrl");
const gameIdInput = document.getElementById("gameId");
const initGameBtn = document.getElementById("initGame");
const killBossBtn = document.getElementById("killBoss");
const stopGameBtn = document.getElementById("stopGame");
const loginResponseArea = document.getElementById("loginResponse");
const initResponseArea = document.getElementById("initResponse");
const gameResponseArea = document.getElementById("gameResponse");
const responseLogArea = document.getElementById("responseLogArea");
const clearLogBtn = document.getElementById("clearLog");
const connectWebSocketBtn = document.getElementById("connectWebSocket");
const disconnectWebSocketBtn = document.getElementById("disconnectWebSocket");
const endGameBtn = document.getElementById("endGameBtn");
const websocketStatusArea = document.getElementById("websocketStatus");

// Stream URL Update Elements
const newStreamUrlInput = document.getElementById("newStreamUrl");
const updateStreamUrlBtn = document.getElementById("updateStreamUrl");
const testStreamUrlUpdateBtn = document.getElementById("testStreamUrlUpdate");
const streamUrlResponseArea = document.getElementById("streamUrlResponse");

// Boost System Elements
const boostUsernameInput = document.getElementById("boostUsername");
const boostAmountSelect = document.getElementById("boostAmount");
const boostAstrokidzBtn = document.getElementById("boostAstrokidz");
const boostAquaticansBtn = document.getElementById("boostAquaticans");
const testBoostBtn = document.getElementById("testBoostBtn");
const connectionStatusBtn = document.getElementById("connectionStatusBtn");
const boostResponseArea = document.getElementById("boostResponse");

// Boost Stats Elements
const currentCycleSpan = document.getElementById("currentCycle");
const astrokidzTotalSpan = document.getElementById("astrokidzTotal");
const aquaticansTotalSpan = document.getElementById("aquaticansTotal");
const cycleTimeRemainingSpan = document.getElementById("cycleTimeRemaining");

// Profile Elements
const fetchProfileBtn = document.getElementById("fetchProfileBtn");
const refreshProfileBtn = document.getElementById("refreshProfileBtn");
const profileResponseArea = document.getElementById("profileResponse");
const profileEmailSpan = document.getElementById("profileEmail");
const profileUsernameSpan = document.getElementById("profileUsername");
const arenaCoinsSpan = document.getElementById("arenaCoins");
const gamesPlayedSpan = document.getElementById("gamesPlayed");
const gamesWonSpan = document.getElementById("gamesWon");
const winRateSpan = document.getElementById("winRate");

// Timestamp Elements
const gameInitializedTimeSpan = document.getElementById("gameInitializedTime");
const websocketConnectedTimeSpan = document.getElementById("websocketConnectedTime");
const arenaBeginsTimeSpan = document.getElementById("arenaBeginsTime");
const currentRoundSpan = document.getElementById("currentRound");
const roundStartTimeSpan = document.getElementById("roundStartTime");
const roundEndTimeSpan = document.getElementById("roundEndTime");
const gameCompletedTimeSpan = document.getElementById("gameCompletedTime");
const totalGameDurationSpan = document.getElementById("totalGameDuration");
const eventTimelineDiv = document.getElementById("eventTimeline");
const clearTimestampsBtn = document.getElementById("clearTimestamps");
const timestampResponseArea = document.getElementById("timestampResponse");

// Game Data Display Elements
const displayGameId = document.getElementById("displayGameId");
const displayGameStatus = document.getElementById("displayGameStatus");
const displayExpiresAt = document.getElementById("displayExpiresAt");
const displayArenaActive = document.getElementById("displayArenaActive");
const displayCountdownStarted = document.getElementById("displayCountdownStarted");
const displayAppName = document.getElementById("displayAppName");
const displayNumberOfCycles = document.getElementById("displayNumberOfCycles");
const displayCycleTime = document.getElementById("displayCycleTime");
const displayWaitingTime = document.getElementById("displayWaitingTime");
const displayIsActive = document.getElementById("displayIsActive");
const playersList = document.getElementById("playersList");
const packagesList = document.getElementById("packagesList");
const eventsList = document.getElementById("eventsList");
const refreshGameDataBtn = document.getElementById("refreshGameData");
const clearGameDataBtn = document.getElementById("clearGameData");
const gameDataResponseArea = document.getElementById("gameDataResponse");

// Item Drop Elements
const purchaserUsernameInput = document.getElementById("purchaserUsername");
const targetPlayerSelect = document.getElementById("targetPlayer");
const immediatePackagesContainer = document.getElementById("immediatePackages");
const itemDropResponseArea = document.getElementById("itemDropResponse");

// Event Trigger Elements
const eventTargetPlayerSelect = document.getElementById("eventTargetPlayer");
const eventButtonsContainer = document.getElementById("eventButtons");
const eventTriggerResponseArea = document.getElementById("eventTriggerResponse");

// Store packages globally for availability checking
let currentPackages = [];

// Store events globally for availability checking
let currentEvents = [];

// JWT Token storage
let jwtToken = localStorage.getItem("jwtToken") || null;

// Game state storage
let currentGameId = localStorage.getItem("currentGameId") || null;
let currentWebSocketUrl = localStorage.getItem("currentWebSocketUrl") || null;

// Timestamp tracking variables
let gameTimestamps = {
  gameInitialized: null,
  websocketConnected: null,
  arenaBegins: null,
  currentRound: 0,
  roundStart: null,
  roundEnd: null,
  gameCompleted: null,
  gameStart: null
};

let eventTimeline = [];
let timelineUpdateInterval = null;

// WebSocket Functions
function connectWebSocket(gameId) {
  if (!gameId) {
    logMessage("No Game ID provided for WebSocket connection", "error");
    return;
  }

  // Close existing connection if any
  if (socket) {
    socket.disconnect();
    socket = null;
  }

  // Determine WebSocket (Socket.IO) base origin URL
  // Prefer the URL provided by the backend when the game was created; else use production server
  const providedUrl = localStorage.getItem("currentWebSocketUrl");
  let wsUrl = `https://vorld-arena-server.onrender.com`;
  if (providedUrl && providedUrl.trim().length > 0) {
    try {
      const parsed = new URL(providedUrl);
      // Convert ws/wss scheme to http/https respectively for Socket.IO client
      if (parsed.protocol === "wss:") {
        parsed.protocol = "https:";
      } else if (parsed.protocol === "ws:") {
        parsed.protocol = "http:";
      }
      // Strip any custom path like /ws/<gameId>; Socket.IO connects to namespace based on path
      wsUrl = `${parsed.protocol}//${parsed.host}`;
    } catch (e) {
      // Fallback to production if parsing fails
      wsUrl = `https://vorld-arena-server.onrender.com`;
    }
  }

  lastWebSocketUrl = wsUrl;
  logMessage(`Connecting to WebSocket: ${wsUrl}`, "info");

  try {
    // Import Socket.IO client dynamically
    const script = document.createElement("script");
    script.src = "https://cdn.socket.io/4.7.4/socket.io.min.js";
    script.onload = () => {
      initializeSocketConnection(wsUrl, gameId);
    };
    script.onerror = () => {
      logMessage("Failed to load Socket.IO client", "error");
    };
    document.head.appendChild(script);
  } catch (error) {
    logMessage(`WebSocket connection error: ${error.message}`, "error");
  }
}

function initializeSocketConnection(wsUrl, gameId) {
  try {
    socket = io(wsUrl, {
      transports: ["websocket", "polling"],
      timeout: 30000,
      forceNew: true,
      reconnection: true,
      reconnectionDelay: 1000,
      reconnectionAttempts: 10,
      reconnectionDelayMax: 5000,
      randomizationFactor: 0.5,
      // Provide auth payload so server can authorize the connection
      auth: {
        token: jwtToken || localStorage.getItem("jwtToken") || undefined,
        gameId: gameId,
        appId: VORLD_APP_ID,
        arenaGameId: (arenaGameIdInput && arenaGameIdInput.value.trim()) || undefined,
      },
    });

    // Connection events
    socket.on("connect", () => {
      isWebSocketConnected = true;
      logMessage(`✅ WebSocket connected! Socket ID: ${socket.id}`, "success");

      // Record WebSocket connection timestamp
      recordTimestamp("websocketConnected", "WebSocket Connected", { socketId: socket.id });

      // Update status display
      websocketStatusArea.className = "status-area connected";
      websocketStatusArea.textContent = `Connected - Socket ID: ${socket.id}`;

      // Join the game room
      socket.emit("join_game", gameId);
      logMessage(`🎮 Joined game room: ${gameId}`, "info");
      
      // Start timeline updates
      startTimelineUpdate();
      
      // Start auto-refresh of boost stats
      startBoostStatsAutoRefresh();
    });

    socket.on("disconnect", (reason) => {
      isWebSocketConnected = false;
      logMessage(`🔌 WebSocket disconnected: ${reason}`, "warning");
      
      // Stop auto-refresh of boost stats
      stopBoostStatsAutoRefresh();

      // Update status display
      websocketStatusArea.className = "status-area disconnected";
      websocketStatusArea.textContent = `Disconnected - ${reason}`;
    });

    socket.on("connect_error", (error) => {
      logMessage(`🚨 WebSocket connection error: ${error.message}`, "error");
    });

    socket.on("reconnect", (attemptNumber) => {
      logMessage(
        `🔄 WebSocket reconnected after ${attemptNumber} attempts`,
        "success"
      );
      // Rejoin game room after reconnection
      socket.emit("join_game", gameId);
    });

    socket.on("reconnect_error", (error) => {
      logMessage(`🚨 WebSocket reconnection error: ${error.message}`, "error");
    });

    // Game Events - Subscribe to ALL available events
    socket.on("arena_countdown_started", (data) => {
      logMessage(
        `⏰ ARENA COUNTDOWN STARTED: ${JSON.stringify(data, null, 2)}`,
        "info"
      );
    });

    socket.on("countdown_update", (data) => {
      logMessage(
        `⏱️ COUNTDOWN UPDATE: ${JSON.stringify(data, null, 2)}`,
        "info"
      );
    });

    socket.on("arena_begins", (data) => {
      logMessage(
        `⚔️ ARENA BEGINS: ${JSON.stringify(data, null, 2)}`,
        "success"
      );
      
      // Record arena begins timestamp
      recordTimestamp("arenaBegins", "Arena Begins", data);
    });

    // Custom test events (emitted 10 seconds after arena_begins)
    socket.on("test_string", (data) => {
      logMessage(
        `🧪 TEST_STRING EVENT: ${JSON.stringify(data, null, 2)}`,
        "success"
      );
      logMessage(`📝 String value: ${data.sarthak}`, "info");
    });

    socket.on("test_number", (data) => {
      logMessage(
        `🧪 TEST_NUMBER EVENT: ${JSON.stringify(data, null, 2)}`,
        "success"
      );
      logMessage(`🔢 Number value: ${data.sarthak}`, "info");
    });

    socket.on("arena_ends", (data) => {
      logMessage(`🏁 ARENA ENDS: ${JSON.stringify(data, null, 2)}`, "warning");

      // Record arena end timestamp
      recordTimestamp("roundEnd", "Arena Ends", data);

      // Arena has ended - prepare for game completion
      logMessage("⚠️ Arena session ended - Game will complete soon", "warning");
    });

    socket.on("game_start", (data) => {
      logMessage(`🎮 GAME START: ${JSON.stringify(data, null, 2)}`, "success");
      
      // Record game start timestamp and update round
      recordTimestamp("gameStart", "Game Start", data);
      if (data.round) {
        gameTimestamps.currentRound = data.round;
        recordTimestamp("roundStart", `Round ${data.round} Start`, data);
      }
    });

    socket.on("game_state_update", (data) => {
      logMessage(
        `📊 GAME STATE UPDATE: ${JSON.stringify(data, null, 2)}`,
        "info"
      );
    });

    socket.on("boost_cycle_reset", (data) => {
      logMessage(
        `🔄 BOOST CYCLE RESET: ${JSON.stringify(data, null, 2)}`,
        "info"
      );
      
      // Record round start when boost cycle resets
      if (data.currentCycle) {
        gameTimestamps.currentRound = data.currentCycle;
        recordTimestamp("roundStart", `Round ${data.currentCycle} Start`, data);
      }
    });

    socket.on("boost_cycle_update", (data) => {
      logMessage(
        `🔄 BOOST CYCLE UPDATE: ${JSON.stringify(data, null, 2)}`,
        "info"
      );
    });

    socket.on("item_unlock", (data) => {
      logMessage(`🎁 ITEM UNLOCK: ${JSON.stringify(data, null, 2)}`, "success");
    });

    socket.on("items_dropped", (data) => {
      logMessage(
        `📦 ITEMS DROPPED: ${JSON.stringify(data, null, 2)}`,
        "success"
      );
    });

    socket.on("monolith_activated", (data) => {
      logMessage(
        `🏛️ MONOLITH ACTIVATED: ${JSON.stringify(data, null, 2)}`,
        "success"
      );
    });

    socket.on("mothercrab_killed", (data) => {
      logMessage(
        `🦀 MOTHERCRAB KILLED: ${JSON.stringify(data, null, 2)}`,
        "success"
      );
    });

    socket.on("objective_update", (data) => {
      logMessage(
        `🎯 OBJECTIVE UPDATE: ${JSON.stringify(data, null, 2)}`,
        "info"
      );
    });

    socket.on("game_completed", (data) => {
      logMessage(
        `🏆 GAME COMPLETED: ${JSON.stringify(data, null, 2)}`,
        "success"
      );

      // Record game completion timestamp
      recordTimestamp("gameCompleted", "Game Completed", data);

      // Show game completion details
      const winner =
        data.winnerFaction === "player"
          ? "ASTROKIDZ (Player)"
          : "AQUATICANS (AI)";
      logMessage(`🎉 WINNER: ${winner}`, "success");
      logMessage(
        `💰 PAYOUT: ${data.payoutInfo?.amount || 0} ${
          data.payoutInfo?.currency || "SOL"
        }`,
        "success"
      );
      logMessage(
        `📊 FINAL SCORES - Astrokidz: ${
          data.finalScores?.astrokidzPoints || 0
        }, Aquaticans: ${data.finalScores?.aquaticansPoints || 0}`,
        "info"
      );

      // Keep connection alive for completed games to continue receiving events
      logMessage(
        "🔚 Game completed - Connection will remain active for further events",
        "info"
      );
      logMessage(
        "💡 Use 'End Game Session' button to manually disconnect when ready",
        "info"
      );
      
      // Stop timeline updates after game completion
      stopTimelineUpdate();
    });

    // Boost System Events
    socket.on("boost_activated", (data) => {
      logMessage(
        `🚀 BOOST ACTIVATED: ${data.boosterUsername} boosted ${data.faction} with ${data.boostAmount} points!`,
        "success"
      );
      logMessage(`🎯 Boost Details: ${JSON.stringify(data, null, 2)}`, "info");
      updateBoostStats({
        currentCyclePoints: data.currentCyclePoints,
        totalPoints: data.totalPoints,
        faction: data.faction,
      });
    });

    socket.on("boost_cycle_reset", (data) => {
      logMessage(
        `🔄 BOOST CYCLE RESET: Cycle ${data.currentCycle} started`,
        "info"
      );
      updateBoostCycleStats(data);
    });

    socket.on("boost_cycle_update", (data) => {
      logMessage(
        `🔄 BOOST CYCLE UPDATE: Cycle ${data.currentCycle} | Player: ${data.playerCurrentCyclePoints}/${data.playerTotalPoints} | Aquaticans: ${data.aquaticanCurrentCyclePoints}/${data.aquaticanTotalPoints} | Time: ${data.timeUntilReset}s`,
        "info"
      );
      logMessage(
        `📊 Boost Cycle Details: ${JSON.stringify(data, null, 2)}`,
        "info"
      );
      updateBoostCycleStats(data);
    });

    // New Player Boost Events
    socket.on("player_boost_activated", (data) => {
      logMessage(
        `🚀 PLAYER BOOST ACTIVATED: ${data.boosterUsername} boosted ${data.playerName} with ${data.boostAmount} points!`,
        "success"
      );
      logMessage(`🎯 Player Boost Details: ${JSON.stringify(data, null, 2)}`, "info");
      
      // Update player boost stats automatically
      updatePlayerBoostStats(data);
      
      // Auto-refresh player boost stats if available
      const gameId = gameIdInput.value.trim();
      if (gameId) {
        setTimeout(() => {
          fetchPlayerBoostStats();
        }, 1000); // Small delay to ensure server has updated
      }
    });

    socket.on("player_boost_stats_updated", (data) => {
      logMessage(
        `📊 PLAYER BOOST STATS UPDATED: ${JSON.stringify(data, null, 2)}`,
        "info"
      );
      updatePlayerBoostStatsDisplay(data);
    });

    socket.on("package_drop", (data) => {
      logMessage(
        `📦 PACKAGE DROP: Cycle ${data.currentCycle} | Astrokidz Package: ${data.astrokidzPackageId} (${data.astrokidzPoints}pts) | Aquaticans Package: ${data.aquaticansPackageId} (${data.aquaticansPoints}pts)`,
        "success"
      );
    });

    socket.on("items_dropped", (data) => {
      const itemsList = data.unlockedItems
        .map((item) => `${item.id} x${item.quantity}`)
        .join(", ");
      logMessage(
        `🎁 ITEMS DROPPED: ${data.faction.toUpperCase()} received ${
          data.unlockedItems.length
        } items: ${itemsList}`,
        "success"
      );
    });

    socket.on("message", (data) => {
      logMessage(`💬 MESSAGE: ${JSON.stringify(data, null, 2)}`, "info");
    });

    // Additional server events that might be missed
    socket.on("error", (error) => {
      logMessage(`❌ SOCKET ERROR: ${JSON.stringify(error, null, 2)}`, "error");
    });

    socket.on("game_expired", (data) => {
      logMessage(
        `⏰ GAME EXPIRED: ${JSON.stringify(data, null, 2)}`,
        "warning"
      );
      logMessage(
        "🔚 Game has expired - Connection will be maintained for any final events",
        "warning"
      );
    });

    socket.on("game_stopped", (data) => {
      logMessage(
        `🛑 GAME STOPPED: ${JSON.stringify(data, null, 2)}`,
        "warning"
      );
      logMessage(
        "🛑 Game has been stopped manually - All cycles and activities have ended",
        "warning"
      );
    });

    socket.on("boost_cycle_complete", (data) => {
      logMessage(
        `🔄 BOOST CYCLE COMPLETE: ${JSON.stringify(data, null, 2)}`,
        "success"
      );
    });

    socket.on("item_drop", (data) => {
      logMessage(`🎁 ITEM DROP: ${JSON.stringify(data, null, 2)}`, "success");
    });

    socket.on("immediate_item_drop", (data) => {
      logMessage(`💰 IMMEDIATE ITEM DROP sarthak: ${JSON.stringify(data, null, 2)}`, "success");
      logMessage(`🎯 Item: ${data.itemName || data.itemId} for player ${data.targetPlayerName || data.targetPlayer}`, "info");
      logMessage(`👤 Purchased by: ${data.purchaserUsername}`, "info");
      logMessage(`💵 Cost: ${data.cost} Arena Coins`, "info");
      
      // Enhanced logging for evaGameData items
      if (data.item && data.item.isFromEvaGameData) {
        logMessage(`🎮 From EVA Game Data: ${data.item.gameData?.appName || 'Unknown Game'}`, "success");
        logMessage(`📊 Item Stats: ${JSON.stringify(data.item.effects?.stats || [], null, 2)}`, "info");
        if (data.item.effects?.image) {
          logMessage(`🖼️ Item Image: ${data.item.effects.image}`, "info");
        }
      }
      
      console.log("💰 IMMEDIATE ITEM DROP: ", data);
    });

    // Stream URL Change Events
    socket.on("stream_url_changed", (data) => {
      logMessage(`🔗 STREAM URL CHANGED: ${JSON.stringify(data, null, 2)}`, "success");
      logMessage(`📺 New stream URL: ${data.newStreamUrl}`, "info");
      logMessage(`👤 Changed by: ${data.changedBy}`, "info");
      logMessage(`⏰ Changed at: ${data.timestamp}`, "info");
      
      // Update the streamer URL input with the new URL
      if (data.newStreamUrl) {
        streamerUrlInput.value = data.newStreamUrl;
        logMessage(`🔄 Stream URL input updated to: ${data.newStreamUrl}`, "info");
      }
    });

    // Event Trigger Events
    socket.on("event_triggered", (data) => {
      logMessage(`🎯 EVENT TRIGGERED: ${JSON.stringify(data, null, 2)}`, "success");
      logMessage(`🎯 Event: ${data.eventName || data.eventId}${data.targetPlayerName ? ` for player ${data.targetPlayerName}` : ''}`, "info");
      logMessage(`👤 Triggered by: ${data.triggeredBy}`, "info");
      if (data.isFinal) {
        logMessage(`🏁 FINAL EVENT - GAME WILL END!`, "error");
      }
      
      console.log("🎯 EVENT TRIGGERED: ", data);
    });

    // Game End Events
    socket.on("game_ended", (data) => {
      logMessage(`🏁 GAME ENDED: ${JSON.stringify(data, null, 2)}`, "error");
      logMessage(`🏁 Reason: ${data.reason}`, "info");
      if (data.finalEvent) {
        logMessage(`🎯 Final Event: ${data.finalEvent}`, "info");
      }
      logMessage(`👤 Triggered by: ${data.triggeredBy}`, "info");
      
      console.log("🏁 GAME ENDED: ", data);
    });

    // Catch-all for any events we might have missed
    socket.onAny((eventName, ...args) => {
      if (
        ![
          "connect",
          "disconnect",
          "reconnect",
          "connect_error",
          "reconnect_error",
        ].includes(eventName)
      ) {
        logMessage(
          `🔍 UNKNOWN EVENT: ${eventName} | Data: ${JSON.stringify(
            args,
            null,
            2
          )}`,
          "info"
        );
      }
    });

    // Note: Socket.IO now has onAny method to catch unhandled events
    logMessage(
      "🎧 WebSocket event listeners configured for ALL events (including catch-all)",
      "info"
    );
  } catch (error) {
    logMessage(
      `Failed to initialize WebSocket connection: ${error.message}`,
      "error"
    );
  }
}

function disconnectWebSocket() {
  if (socket) {
    socket.disconnect();
    socket = null;
    isWebSocketConnected = false;
    logMessage("🔌 WebSocket disconnected", "info");

    // Update status display
    websocketStatusArea.className = "status-area disconnected";
    websocketStatusArea.textContent = "Disconnected";
  }
}

// Load configuration from localStorage on page load
document.addEventListener("DOMContentLoaded", () => {
  loadConfiguration();
  logMessage("Dummy Game Client loaded successfully!", "info");
});

// Save configuration to localStorage
saveConfigBtn.addEventListener("click", () => {
  const config = {
    baseUrl: baseUrlInput.value.trim(),
    authUrl: authUrlInput.value.trim(),
    email: emailInput.value.trim(),
    password: passwordInput.value.trim(),
    arenaGameId: arenaGameIdInput.value.trim(),
  };

  localStorage.setItem("gameClientConfig", JSON.stringify(config));
  logMessage("Configuration saved successfully!", "success");
});

// Load configuration from localStorage
function loadConfiguration() {
  const savedConfig = localStorage.getItem("gameClientConfig");
  if (savedConfig) {
    const config = JSON.parse(savedConfig);
    baseUrlInput.value = config.baseUrl || "";
    authUrlInput.value = config.authUrl || "";
    emailInput.value = config.email || "";
    passwordInput.value = config.password || "";
    arenaGameIdInput.value = config.arenaGameId || "arcade_mg1r9tq6_dddd6827";
    logMessage("Configuration loaded from localStorage", "info");
  }

  // Load saved game state
  if (currentGameId) {
    gameIdInput.value = currentGameId;
    logMessage(`Game ID loaded: ${currentGameId}`, "info");
  }

  if (currentWebSocketUrl) {
    logMessage(`WebSocket URL loaded: ${currentWebSocketUrl}`, "info");
  }

  // Update token status display
  updateTokenStatus();
}

// Login function
loginBtn.addEventListener("click", async () => {
  const authUrl = authUrlInput.value.trim();
  const email = emailInput.value.trim();
  const password = passwordInput.value.trim();

  if (!authUrl || !email || !password) {
    logMessage(
      "Auth URL, Email, and Password are required for login!",
      "error"
    );
    return;
  }

  try {
    loginBtn.disabled = true;
    loginBtn.innerHTML = '<span class="loading"></span> Logging in...';

    // Hash the password before sending to backend
    const hashedPassword = await sha256(password);
    logMessage("Password hashed with SHA-256", "info");

    const response = await fetch(`${authUrl}/api/auth/login`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-vorld-app-id": `${VORLD_APP_ID}`
      },
      body: JSON.stringify({
        email: email,
        password: hashedPassword,
      }),
    });

    const responseText = await response.text();
    let responseData;
    try {
      responseData = JSON.parse(responseText);
    } catch (e) {
      responseData = responseText;
    }

    if (response.ok && responseData.success && responseData.data?.accessToken) {
      jwtToken = responseData.data.accessToken;
      localStorage.setItem("jwtToken", jwtToken);

      loginResponseArea.className = "response-area success";
      loginResponseArea.textContent = `Login successful!\nToken: ${jwtToken.substring(
        0,
        50
      )}...\n\nFull Response:\n${JSON.stringify(responseData, null, 2)}`;

      logMessage("Login successful! JWT token obtained and stored.", "success");
      updateTokenStatus();
      
      // Auto-fetch profile after successful login
      autoFetchProfileAfterLogin();
    } else {
      loginResponseArea.className = "response-area error";
      loginResponseArea.textContent = `Login failed!\nStatus: ${
        response.status
      }\nResponse: ${JSON.stringify(responseData, null, 2)}`;

      logMessage(
        `Login failed: ${
          responseData.error || responseData.message || "Unknown error"
        }`,
        "error"
      );
    }
  } catch (error) {
    loginResponseArea.className = "response-area error";
    loginResponseArea.textContent = `Error: ${error.message}`;
    logMessage(`Login error: ${error.message}`, "error");
  } finally {
    loginBtn.disabled = false;
    loginBtn.textContent = "Login & Get Token";
  }
});

// Update token status display
function updateTokenStatus() {
  if (jwtToken) {
    logMessage(
      `JWT Token available: ${jwtToken.substring(0, 30)}...`,
      "success"
    );
  } else {
    logMessage("No JWT token available. Please login first.", "info");
  }
}

// API request helper function
async function makeApiRequest(endpoint, method = "GET", body = null) {
  const baseUrl = baseUrlInput.value.trim();
  if (!baseUrl) {
    throw new Error("Base URL is required. Please configure it first.");
  }

  if (!jwtToken) {
    throw new Error("JWT token is required. Please login first.");
  }

  const url = `${baseUrl}${endpoint}`;
  const headers = {
    "Content-Type": "application/json",
    Authorization: `Bearer ${jwtToken}`,
    "x-vorld-app-id": VORLD_APP_ID,
  };

  // Add arena arcade game ID header for game client authentication
  const arenaGameId = arenaGameIdInput.value.trim();
  if (arenaGameId) {
    headers["x-arena-arcade-game-id"] = arenaGameId;
  }

  const requestOptions = {
    method,
    headers,
    body: body ? JSON.stringify(body) : null,
  };

  logMessage(`Making ${method} request to: ${url}`, "info");
  if (body) {
    logMessage(`Request body: ${JSON.stringify(body, null, 2)}`, "info");
  }

  try {
    const response = await fetch(url, requestOptions);
    const responseText = await response.text();

    let responseData;
    try {
      responseData = JSON.parse(responseText);
    } catch (e) {
      responseData = responseText;
    }

    const result = {
      status: response.status,
      statusText: response.statusText,
      data: responseData,
      headers: Object.fromEntries(response.headers.entries()),
    };

    logMessage(
      `Response (${response.status}): ${JSON.stringify(result, null, 2)}`,
      response.ok ? "success" : "error"
    );

    return result;
  } catch (error) {
    const errorMessage = `Request failed: ${error.message}`;
    logMessage(errorMessage, "error");
    throw error;
  }
}

// Initialize Game
initGameBtn.addEventListener("click", async () => {
  const streamerUrl = streamerUrlInput.value.trim();
  if (!streamerUrl) {
    logMessage("Streamer URL is required!", "error");
    return;
  }

  try {
    initGameBtn.disabled = true;
    initGameBtn.innerHTML = '<span class="loading"></span> Initializing...';

    const result = await makeApiRequest("/api/games", "POST", {
      streamUrl: streamerUrl,
    });

    if (result.status === 200 || result.status === 201) {
      initResponseArea.className = "response-area success";
      initResponseArea.textContent = JSON.stringify(result.data, null, 2);

      // Record game initialization timestamp
      recordTimestamp("gameInitialized", "Game Initialized", result.data);

      // Display the detailed game data
      displayGameData(result.data);

      // Save game state from response
      if (result.data && result.data.data) {
        const gameData = result.data.data;

        // Save game ID
        if (gameData.gameId) {
          currentGameId = gameData.gameId;
          localStorage.setItem("currentGameId", currentGameId);
          gameIdInput.value = currentGameId;
          logMessage(`Game ID saved: ${currentGameId}`, "success");

          // Connect to WebSocket with the new game ID
          connectWebSocket(currentGameId);
        }

        // Save WebSocket URL (but we'll use production URL)
        if (gameData.websocketUrl) {
          currentWebSocketUrl = gameData.websocketUrl;
          localStorage.setItem("currentWebSocketUrl", currentWebSocketUrl);
          logMessage(`Original WebSocket URL: ${currentWebSocketUrl}`, "info");
          logMessage(
            `Using production WebSocket URL: wss://vorld-arena-server.onrender.com`,
            "info"
          );
        }

        // Log game status
        if (gameData.status) {
          logMessage(`Game status: ${gameData.status}`, "info");
        }

        if (gameData.expiresAt) {
          logMessage(
            `Game expires at: ${new Date(gameData.expiresAt).toLocaleString()}`,
            "info"
          );
        }
      }
    } else {
      initResponseArea.className = "response-area error";
      initResponseArea.textContent = JSON.stringify(result, null, 2);
    }
  } catch (error) {
    initResponseArea.className = "response-area error";
    initResponseArea.textContent = `Error: ${error.message}`;
  } finally {
    initGameBtn.disabled = false;
    initGameBtn.textContent = "Initialize Game";
  }
});


// Kill Boss
killBossBtn.addEventListener("click", async () => {
  await makeGameAction("/api/games/boss-kill/", "Kill Boss");
});

// Stop Game
stopGameBtn.addEventListener("click", async () => {
  await makeStopGameAction();
});

// Update Stream URL
updateStreamUrlBtn.addEventListener("click", async () => {
  await makeStreamUrlUpdateAction();
});

// Test Stream URL Update
testStreamUrlUpdateBtn.addEventListener("click", async () => {
  await makeTestStreamUrlUpdateAction();
});

// Stop Game Action
async function makeStopGameAction() {
  const gameId = gameIdInput.value.trim();
  if (!gameId) {
    logMessage("Game ID is required to stop game!", "error");
    return;
  }

  // Confirmation dialog since stopping is destructive
  if (
    !confirm(
      `⚠️ Are you sure you want to STOP game ${gameId}?\n\nThis will:\n- End the current game session\n- Stop all boost cycles\n- Complete the game immediately\n\nThis action cannot be undone.`
    )
  ) {
    logMessage("🛑 Game stop cancelled by user", "info");
    return;
  }

  const button = event.target;
  const originalText = button.textContent;

  try {
    button.disabled = true;
    button.innerHTML = '<span class="loading"></span> Stopping Game...';

    logMessage(`🛑 Stopping game ${gameId}...`, "warning");

    const result = await makeApiRequest(`/api/games/${gameId}/stop`, "POST");

    if (result.status === 200) {
      gameResponseArea.className = "response-area success";
      gameResponseArea.textContent = JSON.stringify(result.data, null, 2);
      logMessage(`🛑 Game ${gameId} stopped successfully!`, "success");

      // Show stop details if available
      if (result.data && result.data.data) {
        const stopData = result.data.data;
        if (stopData.reason) {
          logMessage(`📋 Stop Reason: ${stopData.reason}`, "info");
        }
        if (stopData.finalStatus) {
          logMessage(`📊 Final Status: ${stopData.finalStatus}`, "info");
        }
      }

      // Ask user if they want to clear game state after stopping
      setTimeout(() => {
        if (
          confirm(
            "Game stopped successfully!\n\nWould you like to clear the game state and disconnect WebSocket?"
          )
        ) {
          clearGameState();
          logMessage("✅ Game state cleared after stop", "success");
        } else {
          logMessage(
            "💡 Game state preserved. Use 'End Game Session' to clear manually",
            "info"
          );
        }
      }, 1000);
    } else {
      gameResponseArea.className = "response-area error";
      gameResponseArea.textContent = JSON.stringify(result, null, 2);
      logMessage(`🛑 Game stop failed with status ${result.status}`, "error");

      // Show error details if available
      if (result.data && result.data.error) {
        logMessage(
          `❌ Error: ${result.data.error.message || result.data.error}`,
          "error"
        );
      }
    }
  } catch (error) {
    gameResponseArea.className = "response-area error";
    gameResponseArea.textContent = `Error: ${error.message}`;
    logMessage(`🛑 Game stop failed: ${error.message}`, "error");
  } finally {
    button.disabled = false;
    button.textContent = originalText;
  }
}

// Generic game action helper
async function makeGameAction(endpoint, actionName) {
  const gameId = gameIdInput.value.trim();
  if (!gameId) {
    logMessage("Game ID is required!", "error");
    return;
  }

  const button = event.target;
  const originalText = button.textContent;

  try {
    button.disabled = true;
    button.innerHTML = `<span class="loading"></span> ${actionName}...`;

    const result = await makeApiRequest(`${endpoint}${gameId}`, "POST");

    if (result.status === 200) {
      gameResponseArea.className = "response-area success";
      gameResponseArea.textContent = JSON.stringify(result.data, null, 2);
      logMessage(`${actionName} successful!`, "success");
    } else {
      gameResponseArea.className = "response-area error";
      gameResponseArea.textContent = JSON.stringify(result, null, 2);
      logMessage(`${actionName} failed with status ${result.status}`, "error");
    }
  } catch (error) {
    gameResponseArea.className = "response-area error";
    gameResponseArea.textContent = `Error: ${error.message}`;
    logMessage(`${actionName} failed: ${error.message}`, "error");
  } finally {
    button.disabled = false;
    button.textContent = originalText;
  }
}

// Stream URL Update Action
async function makeStreamUrlUpdateAction() {
  const gameId = gameIdInput.value.trim();
  const newStreamUrl = newStreamUrlInput.value.trim();

  if (!gameId) {
    logMessage("Game ID is required to update stream URL!", "error");
    return;
  }

  if (!newStreamUrl) {
    logMessage("New stream URL is required!", "error");
    return;
  }

  // Validate stream URL format
  const streamUrlPattern = /^https?:\/\/(www\.)?(twitch\.tv|youtube\.com|kick\.com)\/.+$/;
  if (!streamUrlPattern.test(newStreamUrl)) {
    logMessage("Invalid stream URL format. Must be a valid Twitch, YouTube, or Kick URL!", "error");
    return;
  }

  const button = event.target;
  const originalText = button.textContent;

  try {
    button.disabled = true;
    button.innerHTML = '<span class="loading"></span> Updating Stream URL...';

    logMessage(`🔗 Updating stream URL for game ${gameId} to: ${newStreamUrl}`, "info");

    const result = await makeApiRequest(`/api/games/${gameId}/stream-url`, "PUT", {
      streamUrl: newStreamUrl,
      oldStreamUrl: streamerUrlInput.value.trim() || "Unknown"
    });

    if (result.status === 200) {
      streamUrlResponseArea.className = "response-area success";
      streamUrlResponseArea.textContent = JSON.stringify(result.data, null, 2);
      logMessage(`🔗 Stream URL updated successfully!`, "success");
      
      // Update the original streamer URL input
      streamerUrlInput.value = newStreamUrl;
      logMessage(`🔄 Original stream URL input updated to: ${newStreamUrl}`, "info");
      
      // Clear the new stream URL input
      newStreamUrlInput.value = "";
      
      // Show additional details if available
      if (result.data && result.data.data) {
        const updateData = result.data.data;
        if (updateData.game) {
          logMessage(`📊 Game Status: ${updateData.game.status}`, "info");
        }
        if (updateData.game && updateData.game.streamUrl) {
          logMessage(`📺 Updated Stream URL: ${updateData.game.streamUrl}`, "info");
        }
      }
    } else {
      streamUrlResponseArea.className = "response-area error";
      streamUrlResponseArea.textContent = JSON.stringify(result, null, 2);
      logMessage(`🔗 Stream URL update failed with status ${result.status}`, "error");
      
      // Show error details if available
      if (result.data && result.data.error) {
        logMessage(`❌ Error: ${result.data.error.message || result.data.error}`, "error");
      }
    }
  } catch (error) {
    streamUrlResponseArea.className = "response-area error";
    streamUrlResponseArea.textContent = `Error: ${error.message}`;
    logMessage(`🔗 Stream URL update failed: ${error.message}`, "error");
  } finally {
    button.disabled = false;
    button.textContent = originalText;
  }
}

// Test Stream URL Update Action
async function makeTestStreamUrlUpdateAction() {
  const gameId = gameIdInput.value.trim();

  if (!gameId) {
    logMessage("Game ID is required for stream URL update testing!", "error");
    return;
  }

  if (!isWebSocketConnected) {
    logMessage("❌ WebSocket must be connected to see stream URL change events!", "error");
    return;
  }

  // Auto-fill test data
  const testUrls = [
    "https://twitch.tv/teststreamer" + Math.floor(Math.random() * 1000),
    "https://youtube.com/watch?v=test" + Math.floor(Math.random() * 1000),
    "https://kick.com/teststreamer" + Math.floor(Math.random() * 1000)
  ];
  
  const randomUrl = testUrls[Math.floor(Math.random() * testUrls.length)];
  newStreamUrlInput.value = randomUrl;
  
  logMessage(`🧪 Testing stream URL update with: ${randomUrl}`, "info");
  logMessage("🧪 Watch for stream_url_changed event in logs below...", "info");

  // Add extra event listener specifically for this test
  const testEventHandler = (data) => {
    logMessage(`🧪 TEST SUCCESS! Stream URL change event received: ${JSON.stringify(data, null, 2)}`, "success");
    socket.off("stream_url_changed", testEventHandler);
  };
  socket.on("stream_url_changed", testEventHandler);

  // Trigger the actual update
  await makeStreamUrlUpdateAction();
}

// Logging function
function logMessage(message, type = "info") {
  const timestamp = new Date().toLocaleTimeString();
  const logEntry = `[${timestamp}] ${type.toUpperCase()}: ${message}\n`;

  responseLogArea.textContent += logEntry;
  responseLogArea.scrollTop = responseLogArea.scrollHeight;

  console.log(`[${type.toUpperCase()}] ${message}`);
}

// Timestamp tracking functions
function recordTimestamp(eventType, eventName, data = null) {
  const now = new Date();
  const timestamp = now.getTime();
  
  // Record the timestamp
  gameTimestamps[eventType] = timestamp;
  
  // Add to event timeline
  const timelineEvent = {
    timestamp: now,
    eventType: eventType,
    eventName: eventName,
    data: data,
    timeString: now.toLocaleTimeString()
  };
  
  eventTimeline.push(timelineEvent);
  
  // Update display
  updateTimestampDisplay();
  updateEventTimeline();
  
  // Log the event
  logMessage(`⏰ ${eventName} recorded at ${now.toLocaleTimeString()}`, "info");
}

function updateTimestampDisplay() {
  const now = new Date();
  
  // Update individual timestamp displays
  if (gameTimestamps.gameInitialized) {
    const time = new Date(gameTimestamps.gameInitialized);
    gameInitializedTimeSpan.textContent = time.toLocaleTimeString();
    gameInitializedTimeSpan.className = "stat-value timestamp-value initialized";
  }
  
  if (gameTimestamps.websocketConnected) {
    const time = new Date(gameTimestamps.websocketConnected);
    websocketConnectedTimeSpan.textContent = time.toLocaleTimeString();
    websocketConnectedTimeSpan.className = "stat-value timestamp-value connected";
  }
  
  if (gameTimestamps.arenaBegins) {
    const time = new Date(gameTimestamps.arenaBegins);
    arenaBeginsTimeSpan.textContent = time.toLocaleTimeString();
    arenaBeginsTimeSpan.className = "stat-value timestamp-value arena";
  }
  
  if (gameTimestamps.currentRound > 0) {
    currentRoundSpan.textContent = gameTimestamps.currentRound;
    currentRoundSpan.className = "stat-value timestamp-value round";
  }
  
  if (gameTimestamps.roundStart) {
    const time = new Date(gameTimestamps.roundStart);
    roundStartTimeSpan.textContent = time.toLocaleTimeString();
    roundStartTimeSpan.className = "stat-value timestamp-value round";
  }
  
  if (gameTimestamps.roundEnd) {
    const time = new Date(gameTimestamps.roundEnd);
    roundEndTimeSpan.textContent = time.toLocaleTimeString();
    roundEndTimeSpan.className = "stat-value timestamp-value round";
  }
  
  if (gameTimestamps.gameCompleted) {
    const time = new Date(gameTimestamps.gameCompleted);
    gameCompletedTimeSpan.textContent = time.toLocaleTimeString();
    gameCompletedTimeSpan.className = "stat-value timestamp-value completed";
  }
  
  // Calculate total game duration
  if (gameTimestamps.gameInitialized && gameTimestamps.gameCompleted) {
    const duration = gameTimestamps.gameCompleted - gameTimestamps.gameInitialized;
    const durationString = formatDuration(duration);
    totalGameDurationSpan.textContent = durationString;
    totalGameDurationSpan.className = "stat-value timestamp-value duration";
  } else if (gameTimestamps.gameInitialized) {
    const duration = now.getTime() - gameTimestamps.gameInitialized;
    const durationString = formatDuration(duration);
    totalGameDurationSpan.textContent = durationString + " (ongoing)";
    totalGameDurationSpan.className = "stat-value timestamp-value duration";
  }
}

function updateEventTimeline() {
  eventTimelineDiv.innerHTML = "";
  
  eventTimeline.forEach((event, index) => {
    const eventDiv = document.createElement("div");
    eventDiv.className = `timeline-event ${event.eventType}`;
    
    const timeSpan = document.createElement("span");
    timeSpan.className = "timeline-event-time";
    timeSpan.textContent = event.timeString;
    
    const nameSpan = document.createElement("span");
    nameSpan.className = "timeline-event-name";
    nameSpan.textContent = event.eventName;
    
    const durationSpan = document.createElement("span");
    durationSpan.className = "timeline-event-duration";
    
    if (index > 0) {
      const prevEvent = eventTimeline[index - 1];
      const duration = event.timestamp.getTime() - prevEvent.timestamp.getTime();
      durationSpan.textContent = `+${formatDuration(duration)}`;
    } else {
      durationSpan.textContent = "start";
    }
    
    eventDiv.appendChild(timeSpan);
    eventDiv.appendChild(nameSpan);
    eventDiv.appendChild(durationSpan);
    eventTimelineDiv.appendChild(eventDiv);
  });
  
  // Scroll to bottom
  eventTimelineDiv.scrollTop = eventTimelineDiv.scrollHeight;
}

function formatDuration(milliseconds) {
  const seconds = Math.floor(milliseconds / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  
  if (hours > 0) {
    return `${hours}h ${minutes % 60}m ${seconds % 60}s`;
  } else if (minutes > 0) {
    return `${minutes}m ${seconds % 60}s`;
  } else {
    return `${seconds}s`;
  }
}

function clearTimestamps() {
  gameTimestamps = {
    gameInitialized: null,
    websocketConnected: null,
    arenaBegins: null,
    currentRound: 0,
    roundStart: null,
    roundEnd: null,
    gameCompleted: null,
    gameStart: null
  };
  
  eventTimeline = [];
  
  // Reset display
  gameInitializedTimeSpan.textContent = "--";
  gameInitializedTimeSpan.className = "stat-value";
  websocketConnectedTimeSpan.textContent = "--";
  websocketConnectedTimeSpan.className = "stat-value";
  arenaBeginsTimeSpan.textContent = "--";
  arenaBeginsTimeSpan.className = "stat-value";
  currentRoundSpan.textContent = "--";
  currentRoundSpan.className = "stat-value";
  roundStartTimeSpan.textContent = "--";
  roundStartTimeSpan.className = "stat-value";
  roundEndTimeSpan.textContent = "--";
  roundEndTimeSpan.className = "stat-value";
  gameCompletedTimeSpan.textContent = "--";
  gameCompletedTimeSpan.className = "stat-value";
  totalGameDurationSpan.textContent = "--";
  totalGameDurationSpan.className = "stat-value";
  
  eventTimelineDiv.innerHTML = "";
  
  logMessage("⏰ Timestamps cleared", "info");
}

function startTimelineUpdate() {
  if (timelineUpdateInterval) {
    clearInterval(timelineUpdateInterval);
  }
  
  timelineUpdateInterval = setInterval(() => {
    updateTimestampDisplay();
  }, 1000);
}

function stopTimelineUpdate() {
  if (timelineUpdateInterval) {
    clearInterval(timelineUpdateInterval);
    timelineUpdateInterval = null;
  }
}

// WebSocket connection button
connectWebSocketBtn.addEventListener("click", () => {
  const gameId = gameIdInput.value.trim();
  if (!gameId) {
    logMessage("Please enter a Game ID to connect WebSocket", "error");
    return;
  }
  connectWebSocket(gameId);
});

// WebSocket disconnection button
disconnectWebSocketBtn.addEventListener("click", () => {
  disconnectWebSocket();
});

// End game session button
endGameBtn.addEventListener("click", () => {
  if (
    confirm(
      "Are you sure you want to end the current game session? This will clear the game state and disconnect WebSocket."
    )
  ) {
    logMessage("🔚 Manually ending game session...", "warning");
    clearGameState();
    logMessage("✅ Game session ended successfully", "success");
  }
});

// Boost Astrokidz
boostAstrokidzBtn.addEventListener("click", async () => {
  await makeBoostAction("astrokidz", "Astrokidz");
});

// Boost Aquaticans
boostAquaticansBtn.addEventListener("click", async () => {
  await makeBoostAction("aquaticans", "Aquaticans");
});

// New Player Boost Event Listeners
document.getElementById("boostPlayer").addEventListener("click", async () => {
  await makePlayerBoostAction();
});

document.getElementById("testPlayerBoost").addEventListener("click", async () => {
  await makeTestPlayerBoostAction();
});

document.getElementById("fetchPlayerBoostStats").addEventListener("click", async () => {
  await fetchPlayerBoostStats();
});

document.getElementById("toggleAutoRefresh").addEventListener("click", () => {
  toggleAutoRefresh();
});

document.getElementById("refreshGameDataForBoost").addEventListener("click", async () => {
  await refreshGameDataForBoost();
});

// Test Boost
testBoostBtn.addEventListener("click", async () => {
  const gameId = gameIdInput.value.trim();

  if (!gameId) {
    logMessage("❌ Game ID is required for boost testing!", "error");
    return;
  }

  if (!isWebSocketConnected) {
    logMessage("❌ WebSocket must be connected to see boost events!", "error");
    return;
  }

  // Auto-fill test data if username is empty
  if (!boostUsernameInput.value.trim()) {
    boostUsernameInput.value = "testuser" + Math.floor(Math.random() * 1000);
    logMessage(
      `🧪 Auto-generated test username: ${boostUsernameInput.value}`,
      "info"
    );
  }

  // Set amount to 25 for testing
  boostAmountSelect.value = "25";

  logMessage(
    "🧪 Testing boost functionality with 25 points for Astrokidz...",
    "info"
  );
  logMessage("🧪 Watch for boost_activated event in logs below...", "info");

  // Add extra event listener specifically for this test
  const testEventHandler = (data) => {
    logMessage(
      `🧪 TEST SUCCESS! Boost event received: ${JSON.stringify(data, null, 2)}`,
      "success"
    );
    socket.off("boost_activated", testEventHandler);
  };
  socket.on("boost_activated", testEventHandler);

  await makeBoostAction("astrokidz", "Astrokidz (TEST)");
});

// Connection Status Check
connectionStatusBtn.addEventListener("click", () => {
  logMessage("📡 Checking connection status...", "info");

  if (socket && isWebSocketConnected) {
    logMessage(`✅ WebSocket: CONNECTED (ID: ${socket.id})`, "success");
    logMessage(
      `🔗 Connected to: wss://vorld-arena-server.onrender.com`,
      "success"
    );
    logMessage(`🎮 Game ID: ${currentGameId || "Not set"}`, "info");

    // Test connection by sending a heartbeat
    if (socket.connected) {
      logMessage(
        `💓 Connection test: PASSED - Socket is responsive`,
        "success"
      );

      // List all active event listeners
      const eventNames = socket.eventNames();
      logMessage(`🎧 Active Event Listeners: ${eventNames.join(", ")}`, "info");

      // Check game room membership
      if (currentGameId) {
        logMessage(`🏠 Joined Game Room: ${currentGameId}`, "info");
      }
    } else {
      logMessage(`❌ Connection test: FAILED - Socket not responsive`, "error");
    }
  } else {
    logMessage(`❌ WebSocket: DISCONNECTED`, "error");
    logMessage(
      `💡 Use 'Connect WebSocket' button to establish connection`,
      "info"
    );
  }

  // Check authentication status
  if (jwtToken) {
    logMessage(`🔐 Authentication: VALID (Token available)`, "success");
  } else {
    logMessage(`🔐 Authentication: MISSING (Login required)`, "warning");
  }

  logMessage("📡 Connection status check complete", "info");
});

// Clear log
clearLogBtn.addEventListener("click", () => {
  responseLogArea.textContent = "";
  logMessage("Log cleared", "info");
});

// Clear timestamps
clearTimestampsBtn.addEventListener("click", () => {
  if (confirm("Are you sure you want to clear all timestamps and event timeline?")) {
    clearTimestamps();
  }
});

// Clear game state function
function clearGameState() {
  currentGameId = null;
  currentWebSocketUrl = null;
  localStorage.removeItem("currentGameId");
  localStorage.removeItem("currentWebSocketUrl");
  gameIdInput.value = "";

  // Stop timeline updates
  stopTimelineUpdate();

  // Disconnect WebSocket
  disconnectWebSocket();

  logMessage("Game state cleared", "info");
}

// Keyboard shortcuts
document.addEventListener("keydown", (event) => {
  // Ctrl/Cmd + Enter to initialize game
  if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
    if (document.activeElement === streamerUrlInput) {
      initGameBtn.click();
    }
  }

  // Enter key in game ID field to trigger first action
  if (event.key === "Enter" && document.activeElement === gameIdInput) {
    killBossBtn.click();
  }

  // Enter key in boost username field to trigger boost with current settings
  if (event.key === "Enter" && document.activeElement === boostUsernameInput) {
    if (event.shiftKey) {
      boostAquaticansBtn.click();
    } else {
      boostAstrokidzBtn.click();
    }
  }

  // Ctrl/Cmd + P to fetch profile
  if ((event.ctrlKey || event.metaKey) && event.key === "p") {
    event.preventDefault();
    fetchProfileBtn.click();
  }

  // Ctrl/Cmd + U to update stream URL
  if ((event.ctrlKey || event.metaKey) && event.key === "u") {
    event.preventDefault();
    updateStreamUrlBtn.click();
  }
});

// Auto-save configuration on input change
[baseUrlInput, authUrlInput, emailInput, passwordInput, arenaGameIdInput].forEach((input) => {
  input.addEventListener("blur", () => {
    const config = {
      baseUrl: baseUrlInput.value.trim(),
      authUrl: authUrlInput.value.trim(),
      email: emailInput.value.trim(),
      password: passwordInput.value.trim(),
      arenaGameId: arenaGameIdInput.value.trim(),
    };
    localStorage.setItem("gameClientConfig", JSON.stringify(config));
  });
});

// Generic boost action helper
async function makeBoostAction(faction, factionName) {
  const gameId = gameIdInput.value.trim();
  const username = boostUsernameInput.value.trim();
  const boostAmount = parseInt(boostAmountSelect.value);

  if (!gameId) {
    logMessage("Game ID is required for boosting!", "error");
    return;
  }

  if (!username) {
    logMessage("Username is required for boosting!", "error");
    return;
  }

  if (username.length < 3 || username.length > 30) {
    logMessage("Username must be between 3 and 30 characters!", "error");
    return;
  }

  const button = event.target;
  const originalText = button.textContent;

  try {
    button.disabled = true;
    button.innerHTML = `<span class="loading"></span> Boosting ${factionName}...`;

    const result = await makeApiRequest(
      `/api/games/boost/${faction}/${gameId}`,
      "POST",
      {
        amount: boostAmount,
        username: username,
      }
    );

    if (result.status === 200) {
      boostResponseArea.className = "response-area success";
      boostResponseArea.textContent = JSON.stringify(result.data, null, 2);
      logMessage(
        `${factionName} boost successful! +${boostAmount} points for ${username}`,
        "success"
      );

      // Update local UI with response data
      if (result.data && result.data.data) {
        updateBoostStats({
          currentCyclePoints: result.data.data.currentCyclePoints,
          totalPoints: result.data.data.totalPoints,
          faction: faction === "astrokidz" ? "astrokidz" : "aquaticans",
        });
      }
    } else {
      boostResponseArea.className = "response-area error";
      boostResponseArea.textContent = JSON.stringify(result, null, 2);
      logMessage(
        `${factionName} boost failed with status ${result.status}`,
        "error"
      );
    }
  } catch (error) {
    boostResponseArea.className = "response-area error";
    boostResponseArea.textContent = `Error: ${error.message}`;
    logMessage(`${factionName} boost failed: ${error.message}`, "error");
  } finally {
    button.disabled = false;
    button.textContent = originalText;
  }
}

// Update boost statistics display
function updateBoostStats(data) {
  if (data.faction === "astrokidz") {
    astrokidzTotalSpan.textContent =
      data.totalPoints || astrokidzTotalSpan.textContent;
  } else if (data.faction === "aquaticans") {
    aquaticansTotalSpan.textContent =
      data.totalPoints || aquaticansTotalSpan.textContent;
  }
}

// Update boost cycle statistics
function updateBoostCycleStats(data) {
  currentCycleSpan.textContent = data.currentCycle || "0";
  astrokidzTotalSpan.textContent = data.playerTotalPoints || "0";
  aquaticansTotalSpan.textContent = data.aquaticanTotalPoints || "0";

  if (data.timeUntilReset !== undefined) {
    cycleTimeRemainingSpan.textContent = `${data.timeUntilReset}s`;
  }
}

// New Player Boost Functions
async function makePlayerBoostAction() {
  const gameId = gameIdInput.value.trim();
  const username = boostUsernameInput.value.trim();
  const boostAmount = parseInt(boostAmountSelect.value);
  const targetPlayerId = document.getElementById("boostTargetPlayer").value.trim();

  if (!gameId) {
    logMessage("❌ Game ID is required for player boosting!", "error");
    return;
  }

  if (!username) {
    logMessage("❌ Username is required for player boosting!", "error");
    return;
  }

  if (!targetPlayerId) {
    logMessage("❌ Please select a target player to boost!", "error");
    return;
  }

  // Debug: Log the selected player info
  const selectedPlayerName = document.getElementById("boostTargetPlayer").options[document.getElementById("boostTargetPlayer").selectedIndex].textContent;
  logMessage(`🔍 Debug - Selected Player: ${selectedPlayerName} (ID: ${targetPlayerId})`, "info");
  logMessage(`🔍 Debug - Game ID: ${gameId}`, "info");
  logMessage(`🔍 Debug - Username: ${username}`, "info");
  logMessage(`🔍 Debug - Boost Amount: ${boostAmount}`, "info");

  // Verify player exists in current game data
  if (!verifyPlayerExists(targetPlayerId)) {
    logMessage(`❌ Player "${selectedPlayerName}" (ID: ${targetPlayerId}) not found in current game data`, "error");
    logMessage("💡 Try refreshing the game data to get the latest player list", "info");
    return;
  }

  if (username.length < 3 || username.length > 30) {
    logMessage("❌ Username must be between 3 and 30 characters!", "error");
    return;
  }

  const button = document.getElementById("boostPlayer");
  const originalText = button.textContent;

  try {
    button.disabled = true;
    button.innerHTML = `<span class="loading"></span> Boosting Player...`;

    const result = await makeApiRequest(
      `/api/games/boost/player/${gameId}/${targetPlayerId}`,
      "POST",
      {
        amount: boostAmount,
        username: username,
      }
    );

    if (result.status === 200) {
      boostResponseArea.className = "response-area success";
      boostResponseArea.textContent = JSON.stringify(result.data, null, 2);
      logMessage(
        `🚀 Player boost successful! +${boostAmount} points for player ${result.data.data.playerName} by ${username}`,
        "success"
      );

      // Update player boost stats if available
      if (result.data && result.data.data) {
        updatePlayerBoostStats(result.data.data);
      }
    } else {
      boostResponseArea.className = "response-area error";
      boostResponseArea.textContent = JSON.stringify(result, null, 2);
      
      // Handle specific error cases
      if (result.data && result.data.error) {
        if (result.data.error.message === "Player not found in this game") {
          logMessage(
            `❌ Player boost failed: Player "${selectedPlayerName}" (ID: ${targetPlayerId}) not found in game ${gameId}`,
            "error"
          );
          logMessage("💡 Try refreshing the game data to get updated player list", "info");
        } else {
          logMessage(
            `❌ Player boost failed: ${result.data.error.message}`,
            "error"
          );
        }
      } else {
        logMessage(
          `❌ Player boost failed with status ${result.status}`,
          "error"
        );
      }
    }
  } catch (error) {
    boostResponseArea.className = "response-area error";
    boostResponseArea.textContent = `Error: ${error.message}`;
    logMessage(`❌ Player boost failed: ${error.message}`, "error");
  } finally {
    button.disabled = false;
    button.textContent = originalText;
  }
}

async function makeTestPlayerBoostAction() {
  const gameId = gameIdInput.value.trim();

  if (!gameId) {
    logMessage("❌ Game ID is required for player boost testing!", "error");
    return;
  }

  if (!isWebSocketConnected) {
    logMessage("❌ WebSocket must be connected to see player boost events!", "error");
    return;
  }

  // Auto-fill test data if username is empty
  if (!boostUsernameInput.value.trim()) {
    boostUsernameInput.value = "testuser" + Math.floor(Math.random() * 1000);
    logMessage(
      `🧪 Auto-generated test username: ${boostUsernameInput.value}`,
      "info"
    );
  }

  // Set amount to 25 for testing
  boostAmountSelect.value = "25";

  // Get available players and select the first one
  const targetPlayerSelect = document.getElementById("boostTargetPlayer");
  if (targetPlayerSelect.options.length <= 1) {
    logMessage("❌ No players available for testing. Please fetch game data first!", "error");
    return;
  }

  // Select the first available player
  targetPlayerSelect.selectedIndex = 1;
  const selectedPlayer = targetPlayerSelect.options[targetPlayerSelect.selectedIndex];
  
  logMessage(
    `🧪 Testing player boost functionality with 25 points for ${selectedPlayer.textContent}...`,
    "info"
  );
  logMessage("🧪 Watch for player_boost_activated event in logs below...", "info");

  // Add extra event listener specifically for this test
  const testEventHandler = (data) => {
    logMessage(
      `🧪 TEST SUCCESS! Player boost event received: ${JSON.stringify(data, null, 2)}`,
      "success"
    );
    socket.off("player_boost_activated", testEventHandler);
  };
  socket.on("player_boost_activated", testEventHandler);

  // Trigger the actual boost
  await makePlayerBoostAction();
}

async function fetchPlayerBoostStats() {
  const gameId = gameIdInput.value.trim();

  if (!gameId) {
    logMessage("❌ Game ID is required to fetch player boost stats!", "error");
    return;
  }

  try {
    const result = await makeApiRequest(
      `/api/games/boost/players/stats/${gameId}`,
      "GET"
    );

    if (result.status === 200) {
      logMessage("📊 Player boost stats fetched successfully!", "success");
      updatePlayerBoostStatsDisplay(result.data.data);
    } else {
      logMessage(
        `❌ Failed to fetch player boost stats with status ${result.status}`,
        "error"
      );
    }
  } catch (error) {
    logMessage(`❌ Failed to fetch player boost stats: ${error.message}`, "error");
  }
}

function updatePlayerBoostStats(data) {
  // This function can be called when individual player boost data is received
  // For now, we'll just log the data
  logMessage(`📊 Player boost updated: ${JSON.stringify(data, null, 2)}`, "info");
}

function updatePlayerBoostStatsDisplay(statsData) {
  const playerBoostStatsList = document.getElementById("playerBoostStatsList");
  
  if (!statsData || !statsData.playerStats) {
    playerBoostStatsList.innerHTML = "<div class='player-boost-stat-item'><span class='player-boost-stat-label'>No player boost data available</span></div>";
    return;
  }

  let html = "";
  
  // Add total stats
  html += `
    <div class="player-boost-stat-item">
      <span class="player-boost-stat-label">Total Players:</span>
      <span class="player-boost-stat-value">${statsData.totalPlayers || 0}</span>
    </div>
    <div class="player-boost-stat-item">
      <span class="player-boost-stat-label">Total Boost Points:</span>
      <span class="player-boost-stat-value">${statsData.totalBoostPoints || 0}</span>
    </div>
    <div class="player-boost-stat-item">
      <span class="player-boost-stat-label">Current Cycle:</span>
      <span class="player-boost-stat-value">${statsData.currentCycle || 0}</span>
    </div>
  `;

  // Add individual player stats
  statsData.playerStats.forEach(player => {
    html += `
      <div class="player-boost-item">
        <div class="player-boost-name">${player.playerName}</div>
        <div class="player-boost-points">Cycle: ${player.currentCyclePoints}</div>
        <div class="player-boost-total">Total: ${player.totalPoints}</div>
      </div>
    `;
  });

  playerBoostStatsList.innerHTML = html;
}

// Verify if a player exists in the current game data
function verifyPlayerExists(playerId) {
  // Check if we have game data stored
  const gameData = window.currentGameData;
  if (!gameData || !gameData.evaGameData || !gameData.evaGameData.players) {
    logMessage("⚠️ No EVA game data available for player verification", "warning");
    logMessage("🔍 Game data structure:", "info");
    logMessage(`  - Has gameData: ${!!gameData}`, "info");
    logMessage(`  - Has evaGameData: ${!!gameData?.evaGameData}`, "info");
    logMessage(`  - Has players: ${!!gameData?.evaGameData?.players}`, "info");
    return true; // Allow the request to proceed if we can't verify
  }

  const players = gameData.evaGameData.players;
  const playerExists = players.some(player => player.id === playerId);
  
  if (!playerExists) {
    logMessage(`🔍 Available players in current game:`, "info");
    players.forEach(player => {
      logMessage(`  - ${player.name} (ID: ${player.id})`, "info");
    });
    logMessage(`🎯 Looking for player ID: ${playerId}`, "info");
  }
  
  return playerExists;
}

// Refresh game data specifically for boost functionality
async function refreshGameDataForBoost() {
  const gameId = gameIdInput.value.trim();
  
  if (!gameId) {
    logMessage("❌ Game ID is required to refresh game data!", "error");
    return;
  }

  try {
    logMessage("🔄 Refreshing game data for boost functionality...", "info");
    
    const result = await makeApiRequest(`/api/games/${gameId}`, "GET");
    
    if (result.status === 200) {
      logMessage("✅ Game data refreshed successfully!", "success");
      displayGameData(result);
      logMessage("🎯 Player dropdown has been updated with latest player list", "info");
    } else {
      logMessage(`❌ Failed to refresh game data with status ${result.status}`, "error");
    }
  } catch (error) {
    logMessage(`❌ Failed to refresh game data: ${error.message}`, "error");
  }
}

// Auto-refresh boost stats every 30 seconds when WebSocket is connected
let boostStatsRefreshInterval = null;

function startBoostStatsAutoRefresh() {
  if (boostStatsRefreshInterval) {
    clearInterval(boostStatsRefreshInterval);
  }
  
  boostStatsRefreshInterval = setInterval(() => {
    const gameId = gameIdInput.value.trim();
    if (gameId && isWebSocketConnected) {
      fetchPlayerBoostStats();
    }
  }, 30000); // Refresh every 30 seconds
  
  logMessage("🔄 Auto-refresh of player boost stats started (every 30 seconds)", "info");
}

function stopBoostStatsAutoRefresh() {
  if (boostStatsRefreshInterval) {
    clearInterval(boostStatsRefreshInterval);
    boostStatsRefreshInterval = null;
    logMessage("⏹️ Auto-refresh of player boost stats stopped", "info");
  }
}

// Toggle auto-refresh on/off
let autoRefreshEnabled = true;

function toggleAutoRefresh() {
  const toggleBtn = document.getElementById("toggleAutoRefresh");
  
  if (autoRefreshEnabled) {
    stopBoostStatsAutoRefresh();
    autoRefreshEnabled = false;
    toggleBtn.textContent = "🔄 Auto-Refresh: OFF";
    toggleBtn.className = "btn btn-danger";
    logMessage("⏹️ Auto-refresh disabled", "info");
  } else {
    if (isWebSocketConnected) {
      startBoostStatsAutoRefresh();
      autoRefreshEnabled = true;
      toggleBtn.textContent = "🔄 Auto-Refresh: ON";
      toggleBtn.className = "btn btn-secondary";
      logMessage("🔄 Auto-refresh enabled", "info");
    } else {
      logMessage("❌ WebSocket must be connected to enable auto-refresh", "error");
    }
  }
}

// Auto-save boost username
boostUsernameInput.addEventListener("blur", () => {
  localStorage.setItem("boostUsername", boostUsernameInput.value.trim());
});

// Load saved boost username
const savedUsername = localStorage.getItem("boostUsername");
if (savedUsername) {
  boostUsernameInput.value = savedUsername;
}

// Profile Event Listeners
fetchProfileBtn.addEventListener("click", async () => {
  await fetchProfile();
});

refreshProfileBtn.addEventListener("click", async () => {
  await fetchProfile();
});

// Fetch Profile Function
async function fetchProfile() {
  try {
    fetchProfileBtn.disabled = true;
    fetchProfileBtn.innerHTML = '<span class="loading"></span> Fetching Profile...';

    logMessage("📊 Fetching user profile...", "info");

    const result = await makeApiRequest("/api/profile", "GET");

    if (result.status === 200) {
      profileResponseArea.className = "response-area success";
      profileResponseArea.textContent = JSON.stringify(result.data, null, 2);
      
      // Update profile display
      updateProfileDisplay(result.data);
      
      logMessage("📊 Profile fetched successfully!", "success");
    } else {
      profileResponseArea.className = "response-area error";
      profileResponseArea.textContent = JSON.stringify(result, null, 2);
      logMessage(`📊 Profile fetch failed with status ${result.status}`, "error");
      
      // Show error details if available
      if (result.data && result.data.error) {
        logMessage(`❌ Error: ${result.data.error.message || result.data.error}`, "error");
      }
    }
  } catch (error) {
    profileResponseArea.className = "response-area error";
    profileResponseArea.textContent = `Error: ${error.message}`;
    logMessage(`📊 Profile fetch failed: ${error.message}`, "error");
  } finally {
    fetchProfileBtn.disabled = false;
    fetchProfileBtn.textContent = "📊 Fetch Profile";
  }
}

// Update Profile Display Function
function updateProfileDisplay(profileData) {
  try {
    // Extract profile data from response
    const profile = profileData.data || profileData;
    
    // Update profile fields
    profileEmailSpan.textContent = profile.email || "--";
    profileUsernameSpan.textContent = profile.username || "--";
    
    // Auto-populate purchaser username for item drops
    if (profile.username) {
      purchaserUsernameInput.value = profile.username;
      logMessage(`👤 Purchaser username set to: ${profile.username}`, "info");
    }
    
    // Update arena coins with special highlighting
    const arenaCoins = profile.arenaCoins || 0;
    arenaCoinsSpan.textContent = arenaCoins.toLocaleString();
    arenaCoinsSpan.className = "stat-value arena-coins-highlight";
    
    // Update game statistics
    const gamesPlayed = profile.gamesPlayed || 0;
    const gamesWon = profile.gamesWon || 0;
    
    gamesPlayedSpan.textContent = gamesPlayed;
    gamesWonSpan.textContent = gamesWon;
    
    // Calculate and display win rate
    const winRate = gamesPlayed > 0 ? ((gamesWon / gamesPlayed) * 100).toFixed(1) : "0.0";
    winRateSpan.textContent = `${winRate}%`;
    
    // Log profile summary
    logMessage(`👤 Profile loaded: ${profile.username || profile.email}`, "success");
    logMessage(`💰 Arena Coins: ${arenaCoins.toLocaleString()}`, "success");
    logMessage(`🎮 Games: ${gamesPlayed} played, ${gamesWon} won (${winRate}% win rate)`, "info");
    
  } catch (error) {
    logMessage(`❌ Error updating profile display: ${error.message}`, "error");
  }
}

// Auto-fetch profile after successful login
function autoFetchProfileAfterLogin() {
  if (jwtToken) {
    setTimeout(() => {
      logMessage("🔄 Auto-fetching profile after login...", "info");
      fetchProfile();
    }, 1000);
  }
}

// Game Data Display Functions
function displayGameData(gameResponse) {
  try {
    logMessage("🎮 Displaying game data...", "info");
    
    if (!gameResponse || !gameResponse.data) {
      logMessage("❌ No game data to display", "error");
      return;
    }

    const gameData = gameResponse.data;
    
    // Store game data globally for player verification
    window.currentGameData = gameData;
    
    // Display basic game information
    displayGameId.textContent = gameData.gameId || "--";
    displayGameStatus.textContent = gameData.status || "--";
    displayGameStatus.className = `stat-value status-${gameData.status || 'unknown'}`;
    
    if (gameData.expiresAt) {
      const expiresDate = new Date(gameData.expiresAt);
      displayExpiresAt.textContent = expiresDate.toLocaleString();
    } else {
      displayExpiresAt.textContent = "--";
    }
    
    displayArenaActive.textContent = gameData.arenaActive ? "Yes" : "No";
    displayArenaActive.className = `stat-value boolean-${gameData.arenaActive}`;
    
    displayCountdownStarted.textContent = gameData.countdownStarted ? "Yes" : "No";
    displayCountdownStarted.className = `stat-value boolean-${gameData.countdownStarted}`;

    // Display EVA game details
    if (gameData.evaGameData) {
      const evaData = gameData.evaGameData;
      
      logMessage(`🎮 EVA Game Data: ${JSON.stringify(evaData, null, 2)}`, "info");
      
      displayAppName.textContent = evaData.appName || "--";
      displayNumberOfCycles.textContent = evaData.numberOfCycles || "--";
      displayCycleTime.textContent = evaData.cycleTime ? `${evaData.cycleTime}s` : "--";
      displayWaitingTime.textContent = evaData.waitingTime ? `${evaData.waitingTime}s` : "--";
      displayIsActive.textContent = evaData.isActive ? "Yes" : "No";
      displayIsActive.className = `stat-value boolean-${evaData.isActive}`;

      // Display players
      logMessage(`👥 Players data: ${JSON.stringify(evaData.players, null, 2)}`, "info");
      displayPlayers(evaData.players || []);
      
      // Display packages
      logMessage(`📦 Packages data: ${JSON.stringify(evaData.packages, null, 2)}`, "info");
      displayPackages(evaData.packages || []);
      
      // Display events
      logMessage(`🎯 Events data: ${JSON.stringify(evaData.events, null, 2)}`, "info");
      displayEvents(evaData.events || []);
      
              // Create immediate package buttons
              createImmediatePackageButtons(gameData);
              
              // Populate player dropdown
              populatePlayerDropdown(gameData);
              
              // Create event buttons
              createEventButtons(gameData);
              
              // Populate event target player dropdown
              populateEventTargetPlayerDropdown(gameData);
              
              // Populate boost target player dropdown
              populateBoostTargetPlayerDropdown(gameData);
              
              // Auto-fetch player boost stats when game data is loaded
              const gameId = gameIdInput.value.trim();
              if (gameId) {
                setTimeout(() => {
                  fetchPlayerBoostStats();
                }, 500); // Small delay to ensure game data is fully processed
              }
    } else {
      logMessage("❌ No evaGameData found in game data", "error");
    }

    logMessage("✅ Game data displayed successfully", "success");
  } catch (error) {
    logMessage(`❌ Error displaying game data: ${error.message}`, "error");
  }
}

function displayPlayers(players) {
  logMessage(`🎮 Displaying players: ${JSON.stringify(players, null, 2)}`, "info");
  playersList.innerHTML = "";
  
  if (!players || players.length === 0) {
    logMessage("❌ No players data to display", "warning");
    playersList.innerHTML = '<div class="player-item"><div class="player-name">No players found</div></div>';
    return;
  }

  players.forEach(player => {
    const playerDiv = document.createElement("div");
    playerDiv.className = "player-item player-active";
    
    playerDiv.innerHTML = `
      <div class="player-header">
        <div class="player-name">${player.name || "Unknown Player"}</div>
        <div class="player-id">ID: ${player.id || "N/A"}</div>
      </div>
      <div class="player-details">
        <div class="player-detail">
          <span class="player-detail-label">Created:</span>
          <span class="player-detail-value">${player.createdAt ? new Date(player.createdAt).toLocaleString() : "N/A"}</span>
        </div>
        <div class="player-detail">
          <span class="player-detail-label">Updated:</span>
          <span class="player-detail-value">${player.updatedAt ? new Date(player.updatedAt).toLocaleString() : "N/A"}</span>
        </div>
      </div>
    `;
    
    playersList.appendChild(playerDiv);
  });
}

function displayPackages(packages) {
  logMessage(`🎮 Displaying packages: ${JSON.stringify(packages, null, 2)}`, "info");
  packagesList.innerHTML = "";
  
  if (!packages || packages.length === 0) {
    logMessage("❌ No packages data to display", "warning");
    packagesList.innerHTML = '<div class="package-item"><div class="package-name">No packages found</div></div>';
    return;
  }

  packages.forEach(packageItem => {
    const packageDiv = document.createElement("div");
    packageDiv.className = `package-item package-${packageItem.type || 'immediate'}`;
    
    const statsHtml = packageItem.stats ? packageItem.stats.map(stat => `
      <div class="stat-item-package">
        <span class="stat-name">${stat.name}:</span>
        <span class="stat-value-package">${stat.currentValue}/${stat.maxValue}</span>
      </div>
    `).join('') : '';
    
    const playersHtml = packageItem.players ? packageItem.players.join(', ') : 'None';
    
    packageDiv.innerHTML = `
      <div class="package-header">
        <div class="package-name">${packageItem.name || "Unknown Package"}</div>
        <div class="package-id">ID: ${packageItem.id || "N/A"}</div>
      </div>
      <div class="package-details">
        <div class="package-detail">
          <span class="package-detail-label">Type:</span>
          <span class="package-detail-value">${packageItem.type || "N/A"}</span>
        </div>
        <div class="package-detail">
          <span class="package-detail-label">Cost:</span>
          <span class="package-detail-value">${packageItem.cost || 0} coins</span>
        </div>
        <div class="package-detail">
          <span class="package-detail-label">Players:</span>
          <span class="package-detail-value">${playersHtml}</span>
        </div>
        <div class="package-detail">
          <span class="package-detail-label">Created:</span>
          <span class="package-detail-value">${packageItem.createdAt ? new Date(packageItem.createdAt).toLocaleString() : "N/A"}</span>
        </div>
      </div>
      ${statsHtml ? `
        <div class="package-stats">
          <h4>Stats:</h4>
          ${statsHtml}
        </div>
      ` : ''}
    `;
    
    packagesList.appendChild(packageDiv);
  });
}

function displayEvents(events) {
  eventsList.innerHTML = "";
  
  if (!events || events.length === 0) {
    eventsList.innerHTML = '<div class="event-item"><div class="event-name">No events found</div></div>';
    return;
  }

  events.forEach(event => {
    const eventDiv = document.createElement("div");
    eventDiv.className = `event-item ${event.isFinal ? 'event-final' : 'event-not-final'}`;
    
    eventDiv.innerHTML = `
      <div class="event-header">
        <div class="event-name">${event.eventName || "Unknown Event"}</div>
        <div class="event-id">ID: ${event.id || "N/A"}</div>
      </div>
      <div class="event-details">
        <div class="event-detail">
          <span class="event-detail-label">Final Event:</span>
          <span class="event-detail-value">${event.isFinal ? "Yes" : "No"}</span>
        </div>
        <div class="event-detail">
          <span class="event-detail-label">Created:</span>
          <span class="event-detail-value">${event.createdAt ? new Date(event.createdAt).toLocaleString() : "N/A"}</span>
        </div>
        <div class="event-detail">
          <span class="event-detail-label">Updated:</span>
          <span class="event-detail-value">${event.updatedAt ? new Date(event.updatedAt).toLocaleString() : "N/A"}</span>
        </div>
      </div>
    `;
    
    eventsList.appendChild(eventDiv);
  });
}

function clearGameDataDisplay() {
  // Clear basic game info
  displayGameId.textContent = "--";
  displayGameStatus.textContent = "--";
  displayGameStatus.className = "stat-value";
  displayExpiresAt.textContent = "--";
  displayArenaActive.textContent = "--";
  displayArenaActive.className = "stat-value";
  displayCountdownStarted.textContent = "--";
  displayCountdownStarted.className = "stat-value";

  // Clear EVA game details
  displayAppName.textContent = "--";
  displayNumberOfCycles.textContent = "--";
  displayCycleTime.textContent = "--";
  displayWaitingTime.textContent = "--";
  displayIsActive.textContent = "--";
  displayIsActive.className = "stat-value";

  // Clear lists
  playersList.innerHTML = "";
  packagesList.innerHTML = "";
  eventsList.innerHTML = "";

  logMessage("🗑️ Game data display cleared", "info");
}

// Game Data Event Listeners
refreshGameDataBtn.addEventListener("click", async () => {
  const gameId = gameIdInput.value.trim();
  if (!gameId) {
    logMessage("❌ Game ID is required to refresh game data!", "error");
    return;
  }

  try {
    refreshGameDataBtn.disabled = true;
    refreshGameDataBtn.innerHTML = '<span class="loading"></span> Refreshing...';

    logMessage("🔄 Refreshing game data...", "info");

    const result = await makeApiRequest(`/api/games/${gameId}`, "GET");

    if (result.status === 200) {
      gameDataResponseArea.className = "response-area success";
      gameDataResponseArea.textContent = JSON.stringify(result.data, null, 2);
      
      // Display the refreshed game data
      displayGameData(result.data);
      
      logMessage("✅ Game data refreshed successfully!", "success");
    } else {
      gameDataResponseArea.className = "response-area error";
      gameDataResponseArea.textContent = JSON.stringify(result.data, null, 2);
      logMessage(`❌ Failed to refresh game data with status ${result.status}`, "error");
    }
  } catch (error) {
    gameDataResponseArea.className = "response-area error";
    gameDataResponseArea.textContent = `Error: ${error.message}`;
    logMessage(`❌ Error refreshing game data: ${error.message}`, "error");
  } finally {
    refreshGameDataBtn.disabled = false;
    refreshGameDataBtn.textContent = "🔄 Refresh Game Data";
  }
});

clearGameDataBtn.addEventListener("click", () => {
  if (confirm("Are you sure you want to clear all game data display?")) {
    clearGameDataDisplay();
  }
});

// Add some helpful tips
logMessage(
  "💡 Tips: Login first to get JWT token before making API calls",
  "info"
);
logMessage(
  "💡 Tips: Use Ctrl+Enter in Streamer URL field to initialize game quickly",
  "info"
);
logMessage(
  "💡 Tips: Use Enter in Game ID field to activate Monolith 1 quickly",
  "info"
);
logMessage(
  "💡 Tips: Configuration is auto-saved when you leave input fields",
  "info"
);
logMessage(
  "💡 Tips: Game ID and WebSocket URL are automatically saved after game initialization",
  "info"
);
logMessage(
  "💡 Tips: WebSocket will automatically connect to production server when game is initialized",
  "info"
);
logMessage("💡 Tips: All WebSocket events will be logged in real-time", "info");
logMessage(
  "💡 Tips: Boost system supports amounts: 25, 50, 100, 500, 5000 points",
  "info"
);
logMessage(
  "💡 Tips: Username is required for boost attribution and saved automatically",
  "info"
);
logMessage(
  "💡 Tips: Connection stays active after game completion to receive all events",
  "info"
);
logMessage(
  "💡 Tips: Use 'End Game Session' button to manually end and reset game state",
  "info"
);
logMessage(
  "💡 Tips: Use 'Check Connection Status' to diagnose connection issues",
  "info"
);
logMessage(
  "💡 Tips: Test Boost button will auto-generate username and test boost functionality",
  "info"
);
logMessage(
  "💡 Tips: Stop Game button will immediately end the game and stop all cycles",
  "info"
);
logMessage(
  "💡 Tips: Profile will be auto-fetched after login, or use 'Fetch Profile' button manually",
  "info"
);
logMessage(
  "💡 Tips: Arena Coins are highlighted in gold and show your current balance",
  "info"
);
logMessage(
  "💡 Tips: Use Ctrl+P to quickly fetch your profile",
  "info"
);
logMessage(
  "💡 Tips: After arena_begins, test_string and test_number events will be emitted after 10 seconds",
  "info"
);
logMessage(
  "💡 Tips: Game Timestamps section shows real-time tracking of all game events with duration calculations",
  "info"
);
logMessage(
  "💡 Tips: Event Timeline displays chronological order of events with time differences between them",
  "info"
);
logMessage(
  "💡 Tips: Timestamps are automatically recorded for game initialization, WebSocket connection, arena events, and game completion",
  "info"
);
logMessage(
  "💡 Tips: Use 'Clear Timeline' button to reset all timestamp tracking for a new game session",
  "info"
);
logMessage(
  "💡 Tips: Stream URL Update section allows you to change the stream URL for an active game",
  "info"
);
logMessage(
  "💡 Tips: Stream URL updates will trigger WebSocket events to notify all connected clients",
  "info"
);
logMessage(
  "💡 Tips: Test Stream URL Update button will auto-generate a random valid stream URL for testing",
  "info"
);
logMessage(
  "💡 Tips: Stream URL updates support Twitch, YouTube, and Kick URLs with proper validation",
  "info"
);
logMessage(
  "💡 Tips: After updating stream URL, the original streamer URL input will be automatically updated",
  "info"
);
logMessage(
  "💡 Tips: Use Ctrl+U to quickly update stream URL",
  "info"
);
logMessage(
  "💡 Tips: Arena Arcade Game ID is required for game client authentication - configure it in the Configuration section",
  "info"
);
logMessage(
  "💡 Tips: The Arena Arcade Game ID must match a registered game in the Vorld Auth Backend",
  "info"
);
logMessage(
  "💡 Tips: Game Data Display section shows detailed information about the current game including players, packages, and events",
  "info"
);
logMessage(
  "💡 Tips: Use 'Refresh Game Data' button to get the latest game information from the server",
  "info"
);
logMessage(
  "💡 Tips: Game data is automatically displayed when you initialize a new game",
  "info"
);
logMessage(
  "💡 Tips: Players, packages, and events are displayed with detailed information and visual indicators",
  "info"
);
logMessage(
  "💡 Tips: Package stats show current values and maximum values for each stat",
  "info"
);
logMessage(
  "💡 Tips: Events are color-coded - red border for final events, green for non-final events",
  "info"
);
logMessage(
  "💡 Tips: Use 'Clear Game Data' button to reset the game data display",
  "info"
);
logMessage(
  "💡 Tips: Item Drop System allows you to purchase and immediately drop items during gameplay",
  "info"
);
logMessage(
  "💡 Tips: Available items are automatically loaded when you create a game",
  "info"
);
logMessage(
  "💡 Tips: Purchaser username is automatically set from your logged-in profile",
  "info"
);
logMessage(
  "💡 Tips: Item drops cost Arena Coins and will be deducted from your balance",
  "info"
);
logMessage(
  "💡 Tips: Package availability depends on the selected target player",
  "info"
);
logMessage(
  "💡 Tips: Item drops trigger immediate_item_drop WebSocket events with detailed information",
  "info"
);
logMessage(
  "💡 Tips: Items from evaGameData include enhanced metadata like stats and images",
  "info"
);

// Function to fetch available immediate items for a game
async function fetchAvailableImmediateItems(gameId) {
  if (!gameId) {
    logMessage("❌ Game ID is required to fetch immediate items", "error");
    return;
  }

  const baseUrl = baseUrlInput.value;
  if (!baseUrl) {
    logMessage("❌ Base URL is required", "error");
    return;
  }

  const token = localStorage.getItem("authToken");
  if (!token) {
    logMessage("❌ Authentication token not found. Please login first.", "error");
    return;
  }

  try {
    logMessage(`🔍 Fetching available immediate items for game: ${gameId}`, "info");
    
    const response = await makeApiRequest(
      `${baseUrl}/api/items/immediate/${gameId}`,
      "GET",
      null,
      {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json"
      }
    );

    if (response.status === 200 && response.data.success) {
      const { immediateItems, totalItems } = response.data.data;
      
      logMessage(`✅ Found ${totalItems} available immediate items:`, "success");
      
      immediateItems.forEach((item, index) => {
        logMessage(`📦 ${index + 1}. ${item.name} (${item.id})`, "info");
        logMessage(`   💰 Cost: ${item.price} Arena Coins`, "info");
        logMessage(`   🎯 Faction: ${item.faction}`, "info");
        logMessage(`   📝 Description: ${item.description}`, "info");
        
        if (item.effects && item.effects.stats && item.effects.stats.length > 0) {
          logMessage(`   📊 Stats:`, "info");
          item.effects.stats.forEach(stat => {
            logMessage(`      - ${stat.name}: ${stat.currentValue}/${stat.maxValue} (${stat.description})`, "info");
          });
        }
        
        if (item.effects && item.effects.image) {
          logMessage(`   🖼️ Image: ${item.effects.image}`, "info");
        }
        
        logMessage("", "info"); // Empty line for readability
      });
      
      return immediateItems;
    } else {
      logMessage(`❌ Failed to fetch immediate items: ${response.data.error?.message || 'Unknown error'}`, "error");
      return [];
    }
  } catch (error) {
    logMessage(`❌ Error fetching immediate items: ${error.message}`, "error");
    return [];
  }
}

// Item Drop Functions
async function makeItemDropAction(itemId, targetPlayer) {
  const gameId = gameIdInput.value.trim();

  logMessage(`🔍 Debug - Game ID: ${gameId}`, "info");
  logMessage(`🔍 Debug - Item ID: ${itemId}`, "info");
  logMessage(`🔍 Debug - Target Player: ${targetPlayer}`, "info");
  logMessage(`🔍 Debug - Target Player Type: ${typeof targetPlayer}`, "info");
  logMessage(`🔍 Debug - Target Player Length: ${targetPlayer ? targetPlayer.length : 'undefined'}`, "info");
  logMessage(`🔍 Debug - JWT Token: ${jwtToken ? 'Present' : 'Missing'}`, "info");

  if (!gameId) {
    logMessage("❌ Game ID is required for item drop!", "error");
    return;
  }

  if (!jwtToken) {
    logMessage("❌ Please login first to drop items!", "error");
    return;
  }

  if (!targetPlayer || targetPlayer.trim() === "") {
    logMessage("❌ Target player is required for item drop!", "error");
    logMessage(`❌ Current targetPlayer value: "${targetPlayer}"`, "error");
    return;
  }

  try {
    logMessage(`💰 Dropping item ${itemId} for player ${targetPlayer}...`, "info");

    const result = await makeApiRequest(`/api/items/drop/${gameId}`, "POST", {
      itemId: itemId,
      targetPlayer: targetPlayer
    });

    if (result.status === 200) {
      itemDropResponseArea.className = "response-area success";
      itemDropResponseArea.textContent = JSON.stringify(result.data, null, 2);
      logMessage(`💰 Item dropped successfully!`, "success");

      // Show drop details
      if (result.data && result.data.data) {
        const dropData = result.data.data;
        if (dropData.itemDropped) {
          logMessage(`📦 Item: ${dropData.itemDropped.itemName}`, "info");
          logMessage(`🎯 Target Player: ${dropData.itemDropped.targetPlayer}`, "info");
          logMessage(`💵 Cost: ${dropData.itemDropped.cost} Arena Coins`, "info");
        }
        if (dropData.newBalance !== undefined) {
          logMessage(`💰 New Balance: ${dropData.newBalance} Arena Coins`, "info");
        }
      }
    } else {
      itemDropResponseArea.className = "response-area error";
      itemDropResponseArea.textContent = JSON.stringify(result.data, null, 2);
      logMessage(`❌ Item drop failed with status ${result.status}`, "error");

      // Show error details
      if (result.data && result.data.error) {
        logMessage(`❌ Error: ${result.data.error.message || result.data.error}`, "error");
      }
    }
  } catch (error) {
    itemDropResponseArea.className = "response-area error";
    itemDropResponseArea.textContent = `Error: ${error.message}`;
    logMessage(`❌ Item drop failed: ${error.message}`, "error");
  }
}

// Function to create immediate package buttons
function createImmediatePackageButtons(gameData) {
  if (!gameData || !gameData.evaGameData || !gameData.evaGameData.packages) {
    immediatePackagesContainer.innerHTML = '<div class="no-packages">No immediate packages available</div>';
    return;
  }

  const immediatePackages = gameData.evaGameData.packages.filter(pkg => pkg.type === "immediate");
  
  // Store packages globally for availability checking
  currentPackages = immediatePackages;
  
  if (immediatePackages.length === 0) {
    immediatePackagesContainer.innerHTML = '<div class="no-packages">No immediate packages available</div>';
    return;
  }

  immediatePackagesContainer.innerHTML = '';
  
  immediatePackages.forEach(pkg => {
    const button = document.createElement('button');
    button.className = 'immediate-package-btn';
    button.dataset.itemId = pkg.id;
    button.dataset.cost = pkg.cost;
    
    // Check if package is available for selected player
    const targetPlayer = targetPlayerSelect.value;
    const isAvailable = !targetPlayer || !pkg.players || pkg.players.includes(targetPlayer);
    
    if (!isAvailable) {
      button.classList.add('package-unavailable');
      button.disabled = true;
    } else {
      button.classList.add('package-available');
    }
    
    button.innerHTML = `
      <div class="package-name">1 ${pkg.name}</div>
      <div class="package-cost">${pkg.cost} Arena Coins</div>
      <div class="package-description">${pkg.description || 'Immediate drop package'}</div>
      ${pkg.stats ? `<div class="package-stats">Stats: ${pkg.stats.length} effects</div>` : ''}
      ${pkg.maxInstances ? `<div class="package-max-instances">Max: ${pkg.maxInstances} instances</div>` : ''}
    `;
    
    button.addEventListener('click', () => {
      const currentTargetPlayer = targetPlayerSelect.value;
      logMessage(`🔍 Button clicked - Current target player: "${currentTargetPlayer}"`, "info");
      logMessage(`🔍 Available options: ${Array.from(targetPlayerSelect.options).map(opt => `${opt.value}="${opt.textContent}"`).join(', ')}`, "info");
      
      if (currentTargetPlayer) {
        makeItemDropAction(pkg.id, currentTargetPlayer);
      } else {
        logMessage("❌ Please select a target player first!", "error");
        logMessage(`❌ Current dropdown value: "${currentTargetPlayer}"`, "error");
      }
    });
    
    immediatePackagesContainer.appendChild(button);
  });
}

// Function to populate player dropdown
function populatePlayerDropdown(gameData) {
  logMessage(`🔍 Populating player dropdown with game data:`, "info");
  logMessage(`🔍 Game data: ${JSON.stringify(gameData, null, 2)}`, "info");
  
  if (!gameData || !gameData.evaGameData || !gameData.evaGameData.players) {
    logMessage("❌ No players available in game data", "error");
    targetPlayerSelect.innerHTML = '<option value="">No players available</option>';
    return;
  }

  logMessage(`🔍 Found ${gameData.evaGameData.players.length} players`, "info");
  targetPlayerSelect.innerHTML = '<option value="">Select a player...</option>';
  
  gameData.evaGameData.players.forEach((player, index) => {
    logMessage(`🔍 Adding player ${index + 1}: ${player.id} - ${player.name}`, "info");
    const option = document.createElement('option');
    option.value = player.id;
    option.textContent = player.name;
    targetPlayerSelect.appendChild(option);
  });
  
  logMessage(`🔍 Player dropdown populated with ${targetPlayerSelect.options.length} options`, "info");
}

// Function to populate event target player dropdown
function populateEventTargetPlayerDropdown(gameData) {
  if (!gameData || !gameData.evaGameData || !gameData.evaGameData.players) {
    eventTargetPlayerSelect.innerHTML = '<option value="">No players available</option>';
    return;
  }

  eventTargetPlayerSelect.innerHTML = '<option value="">Select a player (optional)...</option>';
  
  gameData.evaGameData.players.forEach(player => {
    const option = document.createElement('option');
    option.value = player.id;
    option.textContent = player.name;
    eventTargetPlayerSelect.appendChild(option);
  });
}

// Function to populate boost target player dropdown
function populateBoostTargetPlayerDropdown(gameData) {
  const boostTargetPlayerSelect = document.getElementById("boostTargetPlayer");
  
  if (!gameData || !gameData.evaGameData || !gameData.evaGameData.players) {
    boostTargetPlayerSelect.innerHTML = '<option value="">No players available</option>';
    return;
  }

  boostTargetPlayerSelect.innerHTML = '<option value="">Select a player to boost...</option>';
  
  gameData.evaGameData.players.forEach(player => {
    const option = document.createElement('option');
    option.value = player.id;
    option.textContent = player.name;
    boostTargetPlayerSelect.appendChild(option);
  });
  
  logMessage(`🎯 Populated boost target player dropdown with ${gameData.evaGameData.players.length} players`, "info");
}

// Event Trigger Functions
async function triggerEventAction(eventId, targetPlayer) {
  const gameId = gameIdInput.value.trim();

  logMessage(`🔍 Debug - Game ID: ${gameId}`, "info");
  logMessage(`🔍 Debug - Event ID: ${eventId}`, "info");
  logMessage(`🔍 Debug - Target Player: ${targetPlayer || 'None'}`, "info");
  logMessage(`🔍 Debug - JWT Token: ${jwtToken ? 'Present' : 'Missing'}`, "info");

  if (!gameId) {
    logMessage("❌ Game ID is required for event trigger!", "error");
    return;
  }

  if (!jwtToken) {
    logMessage("❌ Please login first to trigger events!", "error");
    return;
  }

  try {
    logMessage(`🎯 Triggering event ${eventId}${targetPlayer ? ` for player ${targetPlayer}` : ''}...`, "info");

    const requestBody = {
      eventId: eventId
    };

    if (targetPlayer) {
      requestBody.targetPlayer = targetPlayer;
    }

    const result = await makeApiRequest(`/api/events/trigger/${gameId}`, "POST", requestBody);

    if (result.status === 200) {
      eventTriggerResponseArea.className = "response-area success";
      eventTriggerResponseArea.textContent = JSON.stringify(result.data, null, 2);
      logMessage(`🎯 Event triggered successfully!`, "success");
    } else {
      eventTriggerResponseArea.className = "response-area error";
      eventTriggerResponseArea.textContent = JSON.stringify(result.data, null, 2);
      logMessage(`❌ Failed to trigger event: ${result.data.error?.message || 'Unknown error'}`, "error");
    }
  } catch (error) {
    eventTriggerResponseArea.className = "response-area error";
    eventTriggerResponseArea.textContent = `Error: ${error.message}`;
    logMessage(`❌ Error triggering event: ${error.message}`, "error");
  }
}

// Function to create event buttons
function createEventButtons(gameData) {
  if (!gameData || !gameData.evaGameData || !gameData.evaGameData.events) {
    eventButtonsContainer.innerHTML = '<div class="no-events">No events available</div>';
    return;
  }

  const events = gameData.evaGameData.events;
  
  // Store events globally for availability checking
  currentEvents = events;
  
  if (events.length === 0) {
    eventButtonsContainer.innerHTML = '<div class="no-events">No events available</div>';
    return;
  }

  eventButtonsContainer.innerHTML = '';
  
  events.forEach(event => {
    const button = document.createElement('button');
    button.className = `event-button ${event.isFinal ? 'event-final' : 'event-not-final'}`;
    button.dataset.eventId = event.id;
    
    button.innerHTML = `
      <div class="event-name">${event.eventName || event.name || 'Unknown Event'}</div>
      <div class="event-description">${event.description || 'Event trigger'}</div>
      ${event.isFinal ? '<div style="color: #dc3545; font-weight: bold; margin-top: 5px;">⚠️ FINAL EVENT - ENDS GAME</div>' : ''}
    `;
    
    button.addEventListener('click', () => {
      const targetPlayer = eventTargetPlayerSelect.value;
      triggerEventAction(event.id, targetPlayer || undefined);
    });
    
    eventButtonsContainer.appendChild(button);
  });
}

// Update package availability when player selection changes
targetPlayerSelect.addEventListener('change', () => {
  const selectedPlayer = targetPlayerSelect.value;
  logMessage(`👤 Player selected: ${selectedPlayer}`, "info");
  
  // Update package availability without re-fetching data
  updatePackageAvailability();
});

// Function to update package availability without refetching
function updatePackageAvailability() {
  const selectedPlayer = targetPlayerSelect.value;
  const packageButtons = immediatePackagesContainer.querySelectorAll('.immediate-package-btn');
  
  packageButtons.forEach(button => {
    const pkgId = button.dataset.itemId;
    const pkg = getPackageById(pkgId);
    
    if (pkg) {
      let isAvailable = true;
      
      // If package has specific players list, check if target player is included
      if (pkg.players && pkg.players.length > 0) {
        isAvailable = pkg.players.includes(selectedPlayer);
      }
      
      if (!isAvailable) {
        button.classList.remove('package-available');
        button.classList.add('package-unavailable');
        button.disabled = true;
        logMessage(`📦 Package ${pkg.name}: DISABLED for player ${selectedPlayer}`, "warning");
      } else {
        button.classList.remove('package-unavailable');
        button.classList.add('package-available');
        button.disabled = false;
        logMessage(`📦 Package ${pkg.name}: ENABLED for player ${selectedPlayer}`, "success");
      }
    }
  });
}

// Helper function to get package by ID
function getPackageById(pkgId) {
  return currentPackages.find(pkg => pkg.id === pkgId);
}

