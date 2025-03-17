<script>
    import { onMount } from "svelte";
    import Chart from "chart.js/auto";
    import 'bootstrap/dist/css/bootstrap.min.css';

    let sensorData = [];
    let predictionData = [];
    let selectedRange = "7d";
    let tempChart, humidityChart, oxygenChart, co2Chart, lightChart;
    let isMobile = false; // Default value

    // 🔥 Live sensor values (always the latest!)
    let latestTemperature = "Loading...";
    let latestHumidity = "Loading...";
    let latestOxygen = "Loading...";
    let latestLight = "Loading...";
    let fanMode = null;   // Options: "auto", "on", "off"
    let waterMode = null; // Options: "auto", "on", "off"

    let lastUpdated = "Loading..."; // ✅ Track last updated time

    let isLoading = true;

    let lastValidTimestamp = null;  // ✅ Stores last REAL sensor timestamp
    let lastUpdatedElement;  // 🔥 Store reference to the "Last Updated" element

    let ip = "http://192.168.1.116:8000"
    async function fetchData() {
        try {
            isLoading = true;
            console.log("📡 Fetching Data on Load...");

            const sensorResponse = await fetch(ip + `/api/get_data?range=${selectedRange}`);
            sensorData = await sensorResponse.json();
            console.log("🌐 API Response:", sensorData);

            const predictionResponse = await fetch(ip + "/api/get_predictions");
            predictionData = await predictionResponse.json();
            predictionData = predictionData.reverse();
            console.log("🔮 Prediction Data:", predictionData);

            if (!sensorData || sensorData.length === 0) {
                console.error("❌ API returned empty or invalid data");
                return;
            }

            // Update control states and live sensor values
            updateWaterMode();
            updateFanMode();
            updateLiveSensorValues();

            // Use the last sensor reading to update the "Last Updated" display
            let latestData = sensorData[sensorData.length - 1]; // Last real sensor data point
            let newTimestamp = new Date(latestData.timestamp).toISOString();
            if (newTimestamp !== lastValidTimestamp) {
                lastValidTimestamp = newTimestamp;
                lastUpdated = new Date(latestData.timestamp).toLocaleString();

                if (lastUpdatedElement) {
                    lastUpdatedElement.classList.remove("updated");
                    void lastUpdatedElement.offsetWidth; // Force reflow to restart animation
                    lastUpdatedElement.classList.add("updated");
                }
            }

            formatTimestamps();
            filterDataForChart();

            // 🔥 Force chart update after data is fetched
            if (tempChart) {
                updateCharts();
            } else {
                console.warn("⚠️ Charts not initialized yet. Retrying in 500ms...");
                setTimeout(() => updateCharts(), 500);
            }
        } catch (error) {
            console.error("❌ Error fetching data:", error);
        } finally {
            isLoading = false;
        }
    }




    function updateLiveSensorValues() {
        if (!sensorData || sensorData.length === 0) {
            console.warn("⚠️ No sensor data available for Live Sensors");
            return;
        }

        let latestData = sensorData[sensorData.length - 1]; // Last data point

        console.log("📡 Updating Live Sensor Values:", latestData);

        latestTemperature = latestData?.temperature !== undefined ? latestData.temperature.toFixed(2) + "°C" : "N/A";
        latestHumidity = latestData?.humidity !== undefined ? latestData.humidity.toFixed(2) + "%" : "N/A";
        latestOxygen = latestData?.oxygen_level !== undefined ? latestData.oxygen_level.toFixed(2) + "%" : "N/A";
        latestLight = latestData?.light_illumination !== undefined ? latestData.light_illumination.toFixed(2) + " lx" : "N/A";
    }


    async function updateFanMode(mode) {
        try {
            fanMode = mode; // ✅ Instantly update UI before the request
            const response = await fetch(ip + "/api/set_control_state/", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ fan_mode: mode })
            });

            const data = await response.json();
            console.log("✅ Fan control updated:", data);
            fanMode = data.fan_mode; // ✅ Ensure it's set to the response value
        } catch (error) {
            console.error("❌ Error updating fan control:", error);
        }
    }

    async function updateWaterMode(mode) {
        try {
            waterMode = mode; // ✅ Instantly update UI before the request
            const response = await fetch(ip + "/api/set_control_state/", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ water_mode: mode })
            });

            const data = await response.json();
            console.log("✅ Water control updated:", data);
            waterMode = data.water_mode; // ✅ Ensure it's set to the response value
        } catch (error) {
            console.error("❌ Error updating water control:", error);
        }
    }



    function filterDataForChart() {
        let step = 1;

        if (selectedRange === "1h") {
            step = isMobile ? 1 : 1;
        } else if (selectedRange === "7d") {
            step = isMobile ? 6 : 6;
        } else if (selectedRange === "24h") {
            step = isMobile ? 6 : 6;
        } else if (selectedRange === "30d") {
            step = isMobile ? 1 : 1;
        } else if (selectedRange === "all") {
            step = isMobile ? 6 : 1;
        }

        sensorData = sensorData.filter((_, index) => index % step === 0);
    }

    function formatTimestamps() {
        sensorData.forEach((d) => {
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
        if (!tempChart || !humidityChart || !oxygenChart || !co2Chart || !lightChart) {
            console.warn("⚠️ Some charts are missing, reinitializing...");
            initializeCharts();
        }

        if (sensorData.length === 0) {
            console.warn("⚠️ No sensor data available for charts.");
            return;
        }

        console.log("📊 Updating Charts...");
        const labels = sensorData.map(d => d.formattedTime);
        let predLabels = [];
        let scaledPredData = [];

        if (selectedRange === "7d") {
            predLabels = predictionData.slice(0, 24).map((_, i) => `+${(i + 1)}h`);
            scaledPredData = predictionData.slice(0, 24);
        } else if (selectedRange === "24h") {
            predLabels = predictionData.slice(0, 3).map((_, i) => `+${(i + 1)}h`);
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
                    { label: label, borderColor: color, data: [], fill: false, pointRadius: 0, borderWidth: 2 },
                    { label: "Predicted " + label, borderColor: color, data: [], fill: false, borderWidth: 2, borderDash: [5, 5], pointRadius: 0 }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: { y: { beginAtZero: false } }
            }
        });
    }

    function initializeCharts() {
        console.log("📊 Initializing Charts..."); // Debugging log

        const ctxTemp = document.getElementById("temperatureChart")?.getContext("2d");
        const ctxHumidity = document.getElementById("humidityChart")?.getContext("2d");
        const ctxOxygen = document.getElementById("oxygenChart")?.getContext("2d");
        const ctxCO2 = document.getElementById("co2Chart")?.getContext("2d");
        const ctxLight = document.getElementById("lightChart")?.getContext("2d");

        if (!ctxTemp || !ctxHumidity || !ctxOxygen || !ctxCO2 || !ctxLight) {
            console.error("❌ Some chart canvases were not found in the DOM.");
            return;
        }

        // ✅ Assign charts globally
        tempChart = createChart(ctxTemp, "Temperature (°C)", "red");
        humidityChart = createChart(ctxHumidity, "Humidity (%)", "blue");
        oxygenChart = createChart(ctxOxygen, "Oxygen Level (%)", "green");
        co2Chart = createChart(ctxCO2, "CO2 Level (ppm)", "purple");
        lightChart = createChart(ctxLight, "Light (lx)", "orange");

        console.log("✅ Charts Initialized:", { tempChart, humidityChart, oxygenChart, co2Chart, lightChart });
    }


    function handleWaterDispense() {
        updateWaterMode('+10ml'); // ✅ Call the existing function
        console.log("Water Dispensed!"); // ✅ Debugging log

        setTimeout(() => document.activeElement.blur(), 500); // ✅ Force blur on mobile & desktop
    }



    onMount(() => {

        console.log("🚀 App Mounted! Fetching Data...");
        isMobile = window.innerWidth < 768;

        fetchData(); // Fetch data first

        setTimeout(() => {
            console.log("📊 Delaying Chart Initialization...");
            initializeCharts(); // Wait before initializing charts
            updateCharts(); // Ensure charts update with fresh data
        }, 500); // Add slight delay to ensure charts have valid data
    });



</script>







<div class="container-fluid text-center font-bold p-5 mb-md-5 mb-3" style="color: white; background-color: #0a3622; font-size: 48px">
    Greenhouse Dashboard
</div>

<div class="container">
    <div class="align-items-center d-flex" style="height: 32px;">
        <p bind:this={lastUpdatedElement} class="last-updated text-muted m-0 me-3">
            Last Updated: {lastUpdated}
        </p>

        {#if isLoading}
            <div class="spinner-border text-primary" role="status" style="width: 24px; height: 24px;">
                <span class="visually-hidden">Loading...</span>
            </div>
        {/if}
    </div>


    <div class="mt-md-4 mt-2">

        <div class="row gx-4 gy-4 flex-column flex-md-row">

            <!-- ✅ Live Data (Left, 2x2 Grid) -->
            <div class="col-md-7 d-grid gap-3">
                <h2 class="mb-2">Live Data</h2>

                <div class="row row-cols-2 gx-3 gy-3">
                    <div class="col">
                        <div class="sensor-card text-center">
                            <h3>Temperature</h3>
                            <p class="m-0 fs-4 text-danger">{latestTemperature}</p>
                        </div>
                    </div>
                    <div class="col">
                        <div class="sensor-card text-center">
                            <h3>Humidity</h3>
                            <p class="m-0 fs-4 text-primary">{latestHumidity}</p>
                        </div>
                    </div>
                    <div class="col">
                        <div class="sensor-card text-center">
                            <h3>Oxygen Level</h3>
                            <p class="m-0 fs-4 text-success">{latestOxygen}</p>
                        </div>
                    </div>
                    <div class="col">
                        <div class="sensor-card text-center">
                            <h3>Light Intensity</h3>
                            <p class="m-0 fs-4 text-warning">{latestLight}</p>
                        </div>
                    </div>
                </div>
            </div>

            <!-- ✅ Controls (Right, Stacked 1x2) -->
            <div class="col-md-5 d-flex flex-column gap-3">
                <h2 class="mb-2">Controls</h2>

                <!-- Fan Control -->
                <div class="sensor-card text-center">
                    <h3>Fan Control</h3>
                    <div class="btn-group mt-2">
                        <button class="p-0 align-items-center d-flex btn btn-outline-success {fanMode === 'auto' ? 'active' : ''}" on:click={() => updateFanMode('auto')}>
                            {#if fanMode === 'auto'}
                                <img class="mx-1" src="/smart.png" alt="smart icon" style="border-radius: 16px" width="28px" height="28px"/>
                            {:else }
                                <img class="mx-1" src="/smart2.png" alt="smart icon" style="border-radius: 16px" width="28px" height="28px"/>
                            {/if}
                            Auto
                        </button>
                        <button class="btn btn-outline-primary {fanMode === 'on' ? 'active' : ''}" on:click={() => updateFanMode('on')}>On</button>
                        <button class="btn btn-outline-danger {fanMode === 'off' ? 'active' : ''}" on:click={() => updateFanMode('off')}>Off</button>
                    </div>
                </div>

                <!-- Water Control -->
                <div class="sensor-card text-center">
                    <h3>Water Control</h3>
                    <div class="btn-group mt-2">
                        <!-- ✅ "Auto" and "Off" buttons stay linked -->
                        <button class="p-0 align-items-center d-flex btn btn-outline-success {waterMode === 'auto' ? 'active' : ''}" on:click={() => updateWaterMode('auto')}>
                            {#if waterMode === 'auto'}
                                <img class="mx-1" src="/smart.png" alt="smart icon" style="border-radius: 16px" width="28px" height="28px"/>
                            {:else }
                                <img class="mx-1" src="/smart2.png" alt="smart icon" style="border-radius: 16px" width="28px" height="28px"/>
                            {/if}
                            Auto
                        </button>

                        <button class="btn btn-outline-danger {waterMode === 'off' ? 'active' : ''}"
                                on:click={() => updateWaterMode('off')}>
                            Off
                        </button>
                        <!-- ✅ "Add 10ml" button is SEPARATE from the group -->
                        <button class="water-btn btn btn-outline-info text-center p-0" on:click={handleWaterDispense} style="width: 84px; height: 38px">
                            +10ml
                        </button>
                    </div>




                </div>

            </div>

        </div>
    </div>




    <div class="container mt-5">
        <h2 class="mb-4">Sensor Data Trends</h2>

        <div class="d-flex align-items-center">
            <div class="select-container">
                <select bind:value={selectedRange} on:change={fetchData}>
                    <option value="1h">Last Hour</option>
                    <option value="24h">Last 24 Hours</option>
                    <option value="7d">Last 7 Days</option>
                    <option value="30d">Last 30 Days</option>
                    <option value="all">All Data</option>
                </select>
            </div>
        </div>


        <div class="row row-cols-1 row-cols-md-2 g-3 mt-3">
            <div class="col">
                <div class="chart-container"><canvas id="temperatureChart"></canvas></div>
            </div>
            <div class="col">
                <div class="chart-container"><canvas id="humidityChart"></canvas></div>
            </div>
            <div class="col">
                <div class="chart-container"><canvas id="oxygenChart"></canvas></div>
            </div>
            <div class="col">
                <div class="chart-container"><canvas id="co2Chart"></canvas></div>
            </div>
            <div class="col">
                <div class="chart-container"><canvas id="lightChart"></canvas></div>
            </div>
        </div>
    </div>

    <div class="text-center mt-4">

    </div>

</div>




<footer class="mt-5 font-bold p-md-5 p-4 pb-2 pb-md-2 mb-5" style="color: white; background-color: #0a3622; margin-bottom: 0 !important">
    <div class="mb-4 fw-semibold" style="color: white; font-size: 36px">
        Team Members
    </div>
    <div class="ms-3">
        <div style="color: white; font-size: 20px">
            Arash Ganjei
        </div>
        <div style="color: white; font-size: 20px">
            Alireza Rezai
        </div>
        <div style="color: white; font-size: 20px">
            Mohammad Bagher Mohsenian
        </div>
        <div style="color: white; font-size: 20px">
            Mohammad Javad Kariminia
        </div>
        <div style="color: white; font-size: 20px">
            Nima Chitsaz
        </div>
    </div>
    <div class="mt-5 text-center" style="color: white; font-size: 16px">
        All rights reserved
    </div>
</footer>



<style>
    .water-btn {
        font-size: 16px;
        padding: 10px 20px;
        border: 2px solid #007a7a;
        background: white;
        color: #007a7a;
        cursor: pointer;
        transition: background 0.2s, color 0.2s;
    }

    .water-btn:active {
        background: #007a7a;
        color: white;
    }
    .last-updated {
        font-size: 18px;
        color: #666;  /* ✅ Soft gray */
        text-align: right;
        margin-bottom: 10px;
        transition: opacity 0.5s ease-in-out, transform 0.5s ease-in-out;
    }

    .last-updated.updated {
        opacity: 0.5;
        transform: scale(1.1); /* ✅ Subtle pop effect */
    }



    .btn-group button {
        transition: all 0.2s ease-in-out;
    }

    /* 🔥 Custom Styled Dropdown */
    .select-container {
        position: relative;
        display: inline-block;
    }

    .select-container select {
        background-color: white;
        border: 2px solid #003d2e; /* Dark green border */
        color: #003d2e; /* Dark green text */
        font-weight: bold;
        padding: 8px 12px;
        border-radius: 8px;
        appearance: none; /* ✅ Removes default browser styling */
        cursor: pointer;
        width: 180px; /* ✅ Adjust width */
    }

    /* 🔥 Dropdown Arrow */
    .select-container::after {
        content: "▼";
        position: absolute;
        top: 50%;
        right: 10px;
        transform: translateY(-50%);
        color: #003d2e;
        font-size: 14px;
        pointer-events: none;
    }

    /* 🔥 Hover & Active States */
    .select-container select:hover,
    .select-container select:focus {
        background-color: #f1f1f1;
        border-color: #145214; /* Darker Green */
    }

    body {
        background-color: #f8f9fa; /* Light background for a clean look */
    }

    .container-fluid {
        font-weight: bold;
        padding: 20px 0;
    }

    h2, h3 {
        color: #003d2e; /* Dark green for a professional feel */
    }

    .sensor-card {
        min-height: 120px; /* ✅ Ensures all cards match height */
        background: white;
        box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
        padding: 16px;
        border-radius: 10px;
        /*transition: transform 0.2s ease-in-out;*/
    }

    /*.sensor-card:hover {*/
    /*    transform: scale(1.05); !* Subtle hover effect *!*/
    /*}*/


    .btn-group button {
        width: 84px; /* Make buttons equal width */
        font-weight: bold;
    }

    /* ✅ Fan Control Buttons */
    .btn-outline-success.active {
        background-color: #145214 !important; /* Dark Green */
        color: white !important;
        border: none;
    }

    .btn-outline-primary.active {
        background-color: #2963c3 !important; /* Dark Blue */
        color: white !important;
        border: none;
    }

    .btn-outline-danger.active {
        background-color: #661414 !important; /* Dark Red */
        color: white !important;
        border: none;
    }


    /* ✅ Water Control Buttons */
    .btn-outline-info.active {
        background-color: #007a7a !important; /* Dark Cyan */
        color: white !important;
        border: none;
    }


    .chart-container {
        background: white;
        border-radius: 8px;
        box-shadow: 0px 4px 8px rgba(0, 0, 0, 0.1);
        padding: 10px;
    }

    .chart-container {
        width: 100%;
        height: 300px;
    }
    :global(html, body) {
        margin: 0;
        padding: 0;
    }
    .hover-effect {
        transition: background-color 0.2s ease;
    }

    .hover-effect:hover {
        background-color: #d3d3d3; /* Grey background */
    }
</style>
