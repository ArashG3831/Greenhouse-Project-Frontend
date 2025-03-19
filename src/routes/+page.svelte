<script>
    import { onMount, onDestroy  } from "svelte";
    import Chart from "chart.js/auto";
    import 'bootstrap/dist/css/bootstrap.min.css';

    // ----- THEME TOGGLING SETUP -----
    let theme = "light";  // default theme set to Light Mode

    function setCookie(name, value, days) {
        const expires = new Date(Date.now() + days * 24 * 60 * 60 * 1000).toUTCString();
        document.cookie = name + "=" + encodeURIComponent(value) + "; expires=" + expires + "; path=/";
    }
    function getCookie(name) {
        const value = "; " + document.cookie;
        const parts = value.split("; " + name + "=");
        if (parts.length === 2) return decodeURIComponent(parts.pop().split(";").shift());
    }

    function toggleTheme() {
        theme = theme === "dark" ? "light" : "dark";
        setCookie("theme", theme, 365);
        updateChartThemes();
    }

    function getTextColor() {
        return theme === 'dark' ? '#ffffff' : '#003d2e';
    }
    function getGridColor() {
        return theme === 'dark' ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.1)';
    }

    function updateChartThemes() {
        [tempChart, humidityChart, oxygenChart, co2Chart, lightChart].forEach(chart => {
            if (chart) {
                if (chart.options.scales.x) {
                    chart.options.scales.x.ticks.color = getTextColor();
                    chart.options.scales.x.grid.color = getGridColor();
                }
                if (chart.options.scales.y) {
                    chart.options.scales.y.ticks.color = getTextColor();
                    chart.options.scales.y.grid.color = getGridColor();
                }
                if (chart.options.plugins?.legend?.labels) {
                    chart.options.plugins.legend.labels.color = getTextColor();
                }
                chart.update();
            }
        });
    }
    // ----- END THEME SETUP -----

    let sensorData = [];
    let predictionData = [];
    let selectedRange = "7d";
    let tempChart, humidityChart, oxygenChart, co2Chart, lightChart;
    let isMobile = false;

    // Live sensor values
    let latestTemperature = "Loading...";
    let latestHumidity = "Loading...";
    let latestOxygen = "Loading...";
    let latestLight = "Loading...";

    // Fan & water modes
    let fanMode = null;   // "auto", "on", or "off"
    let waterMode = null; // "auto", "on", or "off"

    // Track "Last Updated" and loading state
    let lastUpdated = "Loading...";
    let isLoading = true;
    let lastValidTimestamp = null;
    let lastUpdatedElement;

    // Track "Dispensing" for the +10ml button
    let dispensing = false;  // true for 1 second after pressing +10ml

    // let ip = "http://5.201.140.68:8091";

    let ip = "https://ghapi.iomahdi.ir"

    async function fetchData() {
        try {
            isLoading = true;
            console.log("📡 Fetching Data...");

            const sensorResponse = await fetch(`${ip}/api/get_data?range=${selectedRange}`);
            sensorData = await sensorResponse.json();

            const predictionResponse = await fetch(ip + "/api/get_predictions");
            predictionData = await predictionResponse.json();
            predictionData = predictionData.reverse();

            if (!sensorData || sensorData.length === 0) {
                console.error("❌ API returned empty or invalid data");
                return;
            }

            // Do NOT call updateWaterMode() or updateFanMode() here so that
            // the toggle buttons don’t flicker on each fetch.
            updateLiveSensorValues();

            // Update "Last Updated"
            let latestData = sensorData[sensorData.length - 1];
            let newTimestamp = new Date(latestData.timestamp).toISOString();
            if (newTimestamp !== lastValidTimestamp) {
                lastValidTimestamp = newTimestamp;
                lastUpdated = new Date(latestData.timestamp).toLocaleString();

                if (lastUpdatedElement) {
                    lastUpdatedElement.classList.remove("updated");
                    void lastUpdatedElement.offsetWidth; // force reflow
                    lastUpdatedElement.classList.add("updated");
                }
            }

            formatTimestamps();
            filterDataForChart();

            if (tempChart) {
                updateCharts();
            } else {
                // Initialize charts once if they haven't been created yet.
                initializeCharts();
                updateCharts();
            }
        } catch (error) {
            console.error("❌ Error fetching data:", error);
        } finally {
            isLoading = false;
        }
    }

    function updateLiveSensorValues() {
        if (!sensorData || sensorData.length === 0) {
            console.warn("⚠️ No sensor data for Live Sensors");
            return;
        }
        let latestData = sensorData[sensorData.length - 1];
        latestTemperature = latestData?.temperature?.toFixed(2) + "°C" || "N/A";
        latestHumidity = latestData?.humidity?.toFixed(2) + "%" || "N/A";
        latestOxygen = latestData?.oxygen_level?.toFixed(2) + "%" || "N/A";
        latestLight = latestData?.light_illumination?.toFixed(2) + " lx" || "N/A";
    }

    async function updateFanMode(mode) {
        try {
            fanMode = mode;
            const response = await fetch(ip + "/api/set_control_state/", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ fan_mode: mode })
            });
            const data = await response.json();
            fanMode = data.fan_mode;
        } catch (error) {
            console.error("❌ Error updating fan control:", error);
        }
    }

    async function updateWaterMode(mode) {
        try {
            waterMode = mode;
            const response = await fetch(ip + "/api/set_control_state/", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ water_mode: mode })
            });
            const data = await response.json();
            waterMode = data.water_mode;
        } catch (error) {
            console.error("❌ Error updating water control:", error);
        }
    }

    async function handleWaterDispense() {
        // Indicate success style for 1 second without affecting waterMode.
        dispensing = true;
        try {
            await fetch(ip + "/api/set_control_state/", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ water_dispense: "+10ml" })
            });
        } catch (err) {
            console.error("❌ Error dispensing water:", err);
        } finally {
            setTimeout(() => {
                dispensing = false;
            }, 1000);
        }
    }

    function filterDataForChart() {
        let step = 1;
        if (selectedRange === "1h") {
            step = 1;
        } else if (selectedRange === "7d") {
            step = 6;
        } else if (selectedRange === "24h") {
            step = 6;
        } else if (selectedRange === "30d") {
            step = 1;
        } else if (selectedRange === "all") {
            step = isMobile ? 6 : 1;
        }
        sensorData = sensorData.filter((_, index) => index % step === 0);
    }

    function formatTimestamps() {
        sensorData.forEach(d => {
            let dateObj = new Date(d.timestamp);
            if (selectedRange === "1h" || selectedRange === "24h") {
                d.formattedTime = dateObj.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
            } else if (selectedRange === "7d") {
                d.formattedTime = dateObj.toLocaleDateString([], { weekday: 'short', hour: '2-digit' });
            } else if (selectedRange === "30d") {
                d.formattedTime = dateObj.toLocaleDateString([], { month: 'short', day: 'numeric' });
            } else if (selectedRange === "all") {
                let weekNumber = getWeekNumber(dateObj);
                d.formattedTime = `Week ${weekNumber}`;
            }
        });
        if (selectedRange === "all") {
            sensorData.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
        }
    }

    function getWeekNumber(date) {
        let start = new Date(date.getFullYear(), 0, 1);
        let diff = date - start;
        return Math.ceil(diff / (7 * 24 * 60 * 60 * 1000));
    }

    function updateCharts() {
        if (sensorData.length === 0) {
            console.warn("⚠️ No sensor data for charts.");
            return;
        }
        const labels = sensorData.map(d => d.formattedTime);
        let predLabels = [];
        let scaledPredData = [];

        if (selectedRange === "7d") {
            predLabels = predictionData.slice(0, 24).map((_, i) => `+${i + 1}h`);
            scaledPredData = predictionData.slice(0, 24);
        } else if (selectedRange === "24h") {
            predLabels = predictionData.slice(0, 3).map((_, i) => `+${i + 1}h`);
            scaledPredData = predictionData.slice(0, 3);
        }

        updateChart(tempChart, labels, predLabels, sensorData.map(d => d.temperature), scaledPredData.map(d => d.temperature));
        updateChart(humidityChart, labels, predLabels, sensorData.map(d => d.humidity), scaledPredData.map(d => d.humidity));
        updateChart(oxygenChart, labels, predLabels, sensorData.map(d => d.oxygen_level), scaledPredData.map(d => d.oxygen_level));
        updateChart(co2Chart, labels, predLabels, sensorData.map(d => d.co2_level), scaledPredData.map(d => d.co2_level));
        updateChart(lightChart, labels, predLabels, sensorData.map(d => d.light_illumination), scaledPredData.map(d => d.light_illumination));
    }

    function updateChart(chart, labels, predLabels, data, predData) {
        let lastRealIndex = data.length;
        let emptyData = new Array(lastRealIndex).fill(null);
        chart.data.labels = [...labels, ...predLabels];
        chart.data.datasets[0].data = data;
        chart.data.datasets[1].data = [...emptyData, ...predData];
        chart.update();
    }

    function createChart(ctx, label, color) {
        return new Chart(ctx, {
            type: "line",
            data: {
                labels: [],
                datasets: [
                    {
                        label,
                        borderColor: color,
                        data: [],
                        fill: false,
                        pointRadius: 0,
                        borderWidth: 2
                    },
                    {
                        label: "Predicted " + label,
                        borderColor: color,
                        data: [],
                        fill: false,
                        borderWidth: 2,
                        borderDash: [5, 5],
                        pointRadius: 0
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: {
                        ticks: { color: getTextColor() },
                        grid: { color: getGridColor() }
                    },
                    y: {
                        beginAtZero: false,
                        ticks: { color: getTextColor() },
                        grid: { color: getGridColor() }
                    }
                },
                plugins: {
                    legend: {
                        labels: { color: getTextColor() }
                    }
                }
            }
        });
    }

    function initializeCharts() {
        const ctxTemp = document.getElementById("temperatureChart")?.getContext("2d");
        const ctxHumidity = document.getElementById("humidityChart")?.getContext("2d");
        const ctxOxygen = document.getElementById("oxygenChart")?.getContext("2d");
        const ctxCO2 = document.getElementById("co2Chart")?.getContext("2d");
        const ctxLight = document.getElementById("lightChart")?.getContext("2d");

        if (!ctxTemp || !ctxHumidity || !ctxOxygen || !ctxCO2 || !ctxLight) {
            console.error("❌ Some chart canvases were not found in the DOM.");
            return;
        }
        tempChart = createChart(ctxTemp, "Temperature (°C)", "red");
        humidityChart = createChart(ctxHumidity, "Humidity (%)", "blue");
        oxygenChart = createChart(ctxOxygen, "Oxygen Level (%)", "green");
        co2Chart = createChart(ctxCO2, "CO2 Level (ppm)", "purple");
        lightChart = createChart(ctxLight, "Light (lx)", "orange");
    }

    import { createEventDispatcher } from 'svelte';

    const dispatch = createEventDispatcher();

    export let options = [
        { value: "1h", label: "Last Hour" },
        { value: "24h", label: "Last 24 Hours" },
        { value: "7d", label: "Last 7 Days" },
        { value: "30d", label: "Last 30 Days" },
        { value: "all", label: "All Data" }
    ];

    let isOpen = false;

    function toggleDropdown() {
        isOpen = !isOpen;
    }

    function selectOption(opt) {
        selectedRange = opt.value;
        dispatch('change', opt.value); // So parent can respond
        isOpen = false;
    }

    function handleClickOutside(event) {
        const dropdown = document.querySelector(".custom-dropdown");
        if (dropdown && !dropdown.contains(event.target)) {
            isOpen = false;
        }
    }

    onMount(() => {
        fetchData();
        // Check for saved theme
        isMobile = window.innerWidth < 768;

        const savedTheme = getCookie("theme");
        if (savedTheme) {
            theme = savedTheme;
        }
        document.addEventListener("click", handleClickOutside);

        // Initialize toggles (if needed)
        updateWaterMode();
        updateFanMode();
        // Initialize charts once on mount
        initializeCharts();
        // Fetch data immediately and then every 5 seconds.
        setInterval(() => {
            fetchData();
        }, 5000);
    });

    // onDestroy(() => {
        // document.removeEventListener("click", handleClickOutside);
    // });
</script>

<svelte:head>
    <link rel="preload" as="image" href="/smart.png" />
    <link rel="preload" as="image" href="/smart2.png" />
</svelte:head>


<!-- Outer wrapper toggles between dark/light -->
<div class={theme}>
    <!-- HEADER -->
    <div class="container-fluid header text-center p-5 mb-md-5 mb-3">
        <div class="mobile-44px fw-bold">Greenhouse Dashboard<span style="font-size: 60%; vertical-align: super;">™</span></div>
        <div class="mt-2 header-subtitle">
            <i>Real-time Environmental Monitoring</i>
        </div>

        <!-- Desktop Theme Toggle -->
        <button style="font-size: 16px"
                on:click={toggleTheme}
                class="theme-toggle d-none d-md-block">
            {#if theme === 'dark'}
                ☀️ Switch to Light Mode
            {:else}
                🌙 Switch to Dark Mode
            {/if}
        </button>

        <!-- Mobile Theme Toggle -->

    </div>

    <div class="container main-content">
        <div class="d-flex align-items-center header-info justify-content-md-start justify-content-between">
            <p bind:this={lastUpdatedElement} class="last-updated m-0 me-3">
                Last Updated:
                {#if isMobile}
                    <br>
                {/if}
                {lastUpdated}

            </p>
            {#if isLoading}
                <div class="spinner-border" role="status" style="width: 27px; height: 27px;">
                    <span class="visually-hidden">Loading...</span>
                </div>
            {/if}
        </div>

        <div class="mt-md-4 mt-2">
            <div class="row gx-4 gy-4 flex-column flex-md-row">
                <!-- Live Data -->
                <div class="col-md-7 d-grid gap-3">
                    <div class="justify-content-between d-flex align-items-center">
                        <h2 class="section-title m-0">Live Data</h2>

                        <button style="font-size: 16px; border-radius: 64px"
                                on:click={toggleTheme}
                                class="theme-toggle-mobile d-block d-md-none m-0">
                            {#if theme === 'dark'}
                                ☀️
                            {:else}
                                🌙
                            {/if}
                        </button>
                    </div>
                    <div class="row row-cols-2 gx-3 gy-3">
                        <div class="col">
                            <div class="sensor-card text-center">
                                <h3>Temperature</h3>
                                <p class="fs-4 text-danger">{latestTemperature}</p>
                            </div>
                        </div>
                        <div class="col">
                            <div class="sensor-card text-center">
                                <h3>Humidity</h3>
                                <p class="fs-4 text-primary">{latestHumidity}</p>
                            </div>
                        </div>
                        <div class="col">
                            <div class="sensor-card text-center h-100">
                                <h3>Oxygen Level</h3>
                                <p class="fs-4 text-success">{latestOxygen}</p>
                            </div>
                        </div>
                        <div class="col">
                            <div class="sensor-card text-center">
                                <h3>Light Intensity</h3>
                                <p class="fs-4 text-warning">{latestLight}</p>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Controls -->
                <div class="col-md-5 d-flex flex-column gap-3">
                    <h2 class="section-title">Controls</h2>

                    <!-- Fan Control -->
                    <div class="sensor-card text-center h-100">
                        <h3>Fan Control</h3>
                        <div class="btn-group mt-2">
                            <button class="p-0 align-items-center d-flex btn btn-outline-success {fanMode === 'auto' ? 'active' : ''}"
                                    on:click={() => updateFanMode('auto')}
                                    style="width: 84px; height: 38px">
                                {#if fanMode === 'auto' || theme === "dark"}
                                    <img class="mx-1" src="/smart.png" alt="smart icon" style="border-radius:16px" width="28" height="28"/>
                                {:else}
                                    <img class="mx-1" src="/smart2.png" alt="smart icon" style="border-radius:16px" width="28" height="28"/>
                                {/if}
                                Auto
                            </button>

                            <button class="btn btn-outline-primary {fanMode === 'on' ? 'active' : ''}"
                                    on:click={() => updateFanMode('on')}
                                    style="width: 84px; height: 38px">
                                On
                            </button>

                            <button class="btn btn-outline-danger {fanMode === 'off' ? 'active' : ''}"
                                    on:click={() => updateFanMode('off')}
                                    style="width: 84px; height: 38px">
                                Off
                            </button>
                        </div>
                    </div>

                    <!-- Water Control -->
                    <div class="sensor-card text-center h-100">
                        <h3>Water Control</h3>
                        <div class="btn-group mt-2">
                            <button class="p-0 align-items-center d-flex btn btn-outline-success {waterMode === 'auto' ? 'active' : ''}"
                                    on:click={() => updateWaterMode('auto')}
                                    style="width: 84px; height: 38px">
                                {#if waterMode === 'auto' || theme === "dark"}
                                    <img class="mx-1" src="/smart.png" alt="smart icon" style="border-radius:16px" width="28" height="28"/>
                                {:else}
                                    <img class="mx-1" src="/smart2.png" alt="smart icon" style="border-radius:16px" width="28" height="28"/>
                                {/if}
                                Auto
                            </button>

                            <button class="btn btn-outline-danger {waterMode === 'off' ? 'active' : ''}"
                                    on:click={() => updateWaterMode('off')}
                                    style="width: 84px; height: 38px">
                                Off
                            </button>

                            <!-- +10ml Button -->
                            <button class="p-0 water-btn btn btn-outline-info"
                                    on:click={handleWaterDispense}
                                    style="width: 84px; height: 38px"
                                    class:dispensing-active={dispensing}>
                                +10ml
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Charts -->
        <div class="mt-5">
            <h2 class="section-title">Sensor Data Trends</h2>
            <!-- Container that holds the dropdown + icon + text -->
            <div class="d-flex align-items-center" style="flex-wrap: nowrap; width: 100%;">
                <!-- Dropdown (fixed size) -->
                <div class="custom-dropdown" style="flex: 0 0 auto;">
                    <button class="dropdown-toggle" on:click={toggleDropdown}>
                        {options.find(o => o.value === selectedRange)?.label || "Select Range"}
                        <span class="arrow">{isOpen ? "▲" : "▼"}</span>
                    </button>
                    {#if isOpen}
                        <ul class="dropdown-list">
                            {#each options as opt}
                                <li class="dropdown-item" on:click={() => selectOption(opt)}>
                                    {opt.label}
                                </li>
                            {/each}
                        </ul>
                    {/if}
                </div>

                <!-- Icon + text container (takes remaining space) -->
                <div class="d-flex align-items-center" style="flex: 1 1 auto; min-width: 0;">
                    <!-- Icon does not shrink -->
                    {#if selectedRange === "7d" || selectedRange === "24h"}
                        <div>
                            {#if theme === "light"}
                                <img class="fade-in mx-2" src="/smart2.png" height="44px">
                            {:else }
                                <img class="fade-in mx-2" src="/smart.png" height="44px">
                            {/if}
                        </div>
                        <span class="fade-in" style="flex: 1 1 auto; min-width: 0; text-overflow: ellipsis;">AI-Powered predictions {#if !isMobile}enabled{/if}</span>
                    {/if}
                </div>
            </div>


            <div class="row row-cols-1 row-cols-md-2 g-3 mt-3">
                <div class="col">
                    <div class="chart-container">
                        <canvas id="temperatureChart"></canvas>
                    </div>
                </div>
                <div class="col">
                    <div class="chart-container">
                        <canvas id="humidityChart"></canvas>
                    </div>
                </div>
                <div class="col">
                    <div class="chart-container">
                        <canvas id="oxygenChart"></canvas>
                    </div>
                </div>
                <div class="col">
                    <div class="chart-container">
                        <canvas id="co2Chart"></canvas>
                    </div>
                </div>
                <div class="col">
                    <div class="chart-container">
                        <canvas id="lightChart"></canvas>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Footer -->
    <footer class="footer p-md-5 p-4 mb-5 mt-md-5 mt-3" style="padding-bottom: 4px !important">
        <div class="fw-semibold mb-4 team-title">Team Members</div>
        <div class="ms-3 team-members">
            <div>Arash Ganjei</div>
            <div>Alireza Rezai</div>
            <div>Mohammad Bagher Mohsenian</div>
            <div>Mohammad Javad Kariminia</div>
            <div>Nima Chitsaz</div>
        </div>
        <div class="text-center mt-5 team-rights">All rights reserved ©</div>
    </footer>
</div>

<style>

    .smart-info {
        display: flex;
        align-items: center;
        /* Prevent the text from wrapping underneath the icon */
        flex-wrap: wrap;
        /* Optionally, add some margin or padding */
        margin-left: 1rem;
    }

    /* Fade in animation similar to last-updated element */
    .fade-in {
        animation: fadeIn 1s;
    }

    @keyframes fadeIn {
        from { opacity: 0; }
        to   { opacity: 1; }
    }
    /* Hover: dark green background */
    .dark .dropdown-item:hover {
        background-color: darkgreen !important;
    }
    :global(.dark) .dropdown-list {
        background-color: #2e2e2e;
    }
    :global(.light) .dropdown-list {
        background-color: #ffffff;
    }

    .custom-dropdown {
        position: relative;
        display: inline-block;
        width: 160px;
    }

    .dropdown-toggle::after {
        display: none;
    }
    .dropdown-toggle {
        width: 100%;
        padding: 8px 12px;
        font-weight: bold;
        border: 2px solid #2e2e2e;
        border-radius: 8px;
        background-color: #ffffff;
        color: #003d2e;
        text-align: left;
        cursor: pointer;

        /* Remove any default arrow from OS or browser */
        -webkit-appearance: none;
        -moz-appearance: none;
        appearance: none;
        background-image: none;
    }

    .dropdown-toggle:hover {
        background-color: #f1f1f1;
    }

    .arrow {
        float: right;
    }

    /* The dropdown list container */
    .dropdown-list {
        position: absolute;
        top: 100%;
        left: 0;
        right: 0;
        border: 2px solid #515151;
        border-radius: 8px;
        background-color: #ffffff;
        margin: 0;
        padding: 0;
        list-style: none;
        z-index: 999;

        /* Ensures the li hover background doesn't exceed the container's rounded corners */
        overflow: hidden;
    }


    .dropdown-item {
        padding: 8px 12px;
        cursor: pointer;
    }
    .dropdown-item:hover {
        background-color: #e0f3e0;
    }
    /* THEME VARIABLES */
    :global(.dark) {
        --bg-color: #2e2e2e;
        --text-color: #ffffff;
        --header-bg: #1c1c1c;
        --header-text: #ffffff;
        --card-bg: #3a3a3a;
        --card-text: #ffffff;
        --button-bg: #555555;
        --button-text: #ffffff;
        --select-bg: #ffffff;
        --select-text: #2e2e2e;
        --chart-grid: rgba(255,255,255,0.2);
        --chart-tick: #ffffff;
    }
    :global(.light) {
        --bg-color: #f8f9fa;
        --text-color: #003d2e;
        --header-bg: #003d2e;  /* Dark green header in light mode */
        --header-text: #ffffff;
        --card-bg: #ffffff;
        --card-text: #003d2e;
        --button-bg: #007a7a;
        --button-text: #ffffff;
        --select-bg: #ffffff;
        --select-text: #003d2e;
        --chart-grid: rgba(0,0,0,0.1);
        --chart-tick: #003d2e;
    }

    /* GLOBAL STYLES */
    body {
        margin: 0;
        padding: 0;
    }
    .dark, .light {
        background-color: var(--bg-color);
        color: var(--text-color);
        min-height: 100vh;
    }
    .header {
        background-color: var(--header-bg);
        color: var(--header-text);
        font-size: 48px;
        white-space: pre-line;
        position: relative;
    }
    .header-subtitle {
        font-size: 20px;
        font-weight: normal;
        opacity: 0.8;
    }
    .main-content {
        padding: 0 15px;
    }
    .section-title, h3 {
        color: var(--text-color);
    }
    .sensor-card {
        min-height: 120px;
        background: var(--card-bg);
        color: var(--card-text);
        box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
        padding: 16px;
        border-radius: 10px;
    }

    /* Water Button styling & states */
    .water-btn {
        font-size: 16px;
        border: 1px solid #2f9595;
        background: var(--card-bg);
        color: #2f9595 !important;
        cursor: pointer;
        transition: background 0.2s, color 0.2s;
    }
    .water-btn:hover {
        background: #d3f9f9;
    }
    /*.water-btn:active {*/
    /*    background: #5be3e3;*/
    /*    color: #ffffff;*/
    /*}*/
    .dispensing-active {
        background-color: #007a7a !important;
        color: #ffffff !important;
    }
    .light .water-btn {
        color: #007a7a;
    }

    /* Dark mode .btn-outline-success styling */
    .dark .btn-outline-success {
        color: #ffffff;
        border-color: #49d544;
    }
    .dark .btn-outline-success.active {
        background-color: #378a34 !important;
        color: #ffffff !important;
    }

    .last-updated {
        font-size: 18px;
        opacity: 1;
    }
    .last-updated.updated {
        animation: fadeIn 1s;
    }
    @keyframes fadeIn {
        from { opacity: 0; }
        to { opacity: 1; }
    }

    .btn-group button {
        transition: all 0.2s ease-in-out;
        width: 84px;
        font-weight: bold;
    }
    .btn-outline-success.active {
        background-color: #208120 !important;
        color: #ffffff !important;
        border: none;
    }
    .btn-outline-primary.active {
        background-color: #2963c3 !important;
        color: #ffffff !important;
        border: none;
    }
    .btn-outline-danger.active {
        background-color: #ae2d2d !important;
        color: #ffffff !important;
        border: none;
    }
    .btn-outline-info.active {
        background-color: #007a7a !important;
        color: #ffffff !important;
        border: none;
    }
    .chart-container {
        background: var(--card-bg);
        border-radius: 8px;
        box-shadow: 0px 4px 8px rgba(0, 0, 0, 0.1);
        padding: 10px;
        width: 100%;
        height: 300px;
    }
    .select-container {
        position: relative;
        display: inline-block;
    }
    .select-container select {
        background-color: var(--select-bg);
        border: 2px solid #003d2e;
        color: var(--select-text);
        font-weight: bold;
        padding: 8px 12px;
        border-radius: 8px;
        appearance: none;
        cursor: pointer;
        width: 180px;
    }
    .select-container::after {
        content: "▼";
        position: absolute;
        top: 50%;
        right: 12px;
        transform: translateY(-50%);
        color: var(--select-text);
        font-size: 14px;
        pointer-events: none;
    }
    .select-container select:hover,
    .select-container select:focus {
        background-color: #f1f1f1;
        border-color: #145214;
    }

    .footer {
        color: var(--header-text);
        background-color: var(--header-bg);
        margin-bottom: 0 !important;
    }
    .team-title {
        font-size: 36px;
    }
    .team-members div {
        font-size: 20px;
        margin-bottom: 5px;
    }
    .team-rights {
        font-size: 16px;
    }

    /* Desktop theme toggle: top-right corner */
    .theme-toggle {
        position: absolute;
        top: 0;
        right: 0;
        margin: 1rem;
        padding: 10px 16px;
        border-radius: 20px;
        font-weight: bold;
        border: none;
        background-color: #007a7a;
        color: #ffffff;
        cursor: pointer;
        transition: background 0.2s;
    }
    .theme-toggle:hover {
        background-color: #009999;
    }
    .theme-toggle-mobile {
        border-radius: 20px;
        font-weight: bold;
        border: none;
        background-color: #007a7a;
        color: #ffffff;
        padding: 10px 16px;
        cursor: pointer;
        transition: background 0.2s;
    }
    .theme-toggle-mobile:hover {
        background-color: #009999;
    }
    @media (max-width: 767px) {
        .mobile-44px {
            font-size: 44px;
        }
        .theme-toggle {
            display: none !important;
        }
    }
</style>
