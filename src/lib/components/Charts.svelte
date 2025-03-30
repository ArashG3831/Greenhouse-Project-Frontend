<script>
    import { onMount } from 'svelte';
    import Chart from 'chart.js/auto';

    // We'll receive these from the parent:
    export let sensorData = [];      // array of sensor objects
    export let predictionData = [];  // array of predicted values
    export let theme;               // 'light' or 'dark'
    export let selectedRange;       // '1h', '24h', etc.

    // chart references
    let tempChart, humidityChart, oxygenChart, co2Chart, lightChart;

    // onMount: create the charts once
    onMount(() => {
        initializeCharts();
        updateAllCharts(); // populate them initially
    });

    // Whenever sensorData/predictionData/theme changes, update the charts
    $: if (tempChart && humidityChart && oxygenChart && co2Chart && lightChart) {
        updateAllCharts();
    }

    // -------------- UTILITY FUNCTIONS ---------------
    function getTextColor() {
        return theme === 'dark' ? '#ffffff' : '#003d2e';
    }
    function getGridColor() {
        return theme === 'dark' ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.1)';
    }

    // -------------- CHART INITIALIZATION ---------------
    function initializeCharts() {
        const ctxTemp     = document.getElementById("temperatureChart")?.getContext("2d");
        const ctxHumidity = document.getElementById("humidityChart")?.getContext("2d");
        const ctxOxygen   = document.getElementById("oxygenChart")?.getContext("2d");
        const ctxCO2      = document.getElementById("co2Chart")?.getContext("2d");
        const ctxLight    = document.getElementById("lightChart")?.getContext("2d");

        if (!ctxTemp || !ctxHumidity || !ctxOxygen || !ctxCO2 || !ctxLight) {
            console.error("Some chart <canvas> elements are missing.");
            return;
        }

        tempChart     = createBaseChart(ctxTemp, "Temperature (°C)",  "red");
        humidityChart = createBaseChart(ctxHumidity, "Humidity (%)",  "blue");
        oxygenChart   = createBaseChart(ctxOxygen, "Oxygen (%)",      "green");
        co2Chart      = createBaseChart(ctxCO2, "CO2 (ppm)",          "purple");
        lightChart    = createBaseChart(ctxLight, "Light (lx)",       "orange");
    }

    // Helper to create a single chart instance
    function createBaseChart(context, label, color) {
        return new Chart(context, {
            type: "line",
            data: {
                labels: [],
                datasets: [
                    {
                        label: label,
                        borderColor: color,
                        data: [],
                        fill: false,
                        borderWidth: 2,
                        pointRadius: 0,
                        pointHitRadius: 10,
                        pointHoverRadius: 5
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
                    },
                    tooltip: { enabled: true }
                }
            }
        });
    }

    // -------------- CHART UPDATE ---------------
    function updateAllCharts() {
        // figure out your labels and data sets
        // typically, you have your sensorData or some processed array of labels
        // but here, let's assume sensorData has:
        //    d.formattedTime => the x-axis label
        //    d.temperature, d.humidity, d.oxygen_level, etc.

        const labels = sensorData.map(d => d.formattedTime);

        // For predictions, maybe you only have them for certain ranges
        let predLabels = [];
        let scaledPredData = [];

        if (selectedRange === "7d") {
            // example: use first 24 predictions
            predLabels = predictionData.slice(0, 24).map((_, i) => `+${i+1}h`);
            scaledPredData = predictionData.slice(0, 24);
        } else if (selectedRange === "24h") {
            // example: use first 3 predictions
            predLabels = predictionData.slice(0, 3).map((_, i) => `+${i+1}h`);
            scaledPredData = predictionData.slice(0, 3);
        }
        // else => no predictions, etc.

        // Update each chart
        updateChart(tempChart,
            labels, predLabels,
            sensorData.map(d => d.temperature),
            scaledPredData.map(d => d.temperature)
        );

        updateChart(humidityChart,
            labels, predLabels,
            sensorData.map(d => d.humidity),
            scaledPredData.map(d => d.humidity)
        );

        updateChart(oxygenChart,
            labels, predLabels,
            sensorData.map(d => d.oxygen_level),
            scaledPredData.map(d => d.oxygen_level)
        );

        updateChart(co2Chart,
            labels, predLabels,
            sensorData.map(d => d.co2_level),
            scaledPredData.map(d => d.co2_level)
        );

        updateChart(lightChart,
            labels, predLabels,
            sensorData.map(d => d.light_illumination),
            scaledPredData.map(d => d.light_illumination)
        );
    }

    function updateChart(chart, labels, predLabels, realData, predData) {
        if (!chart) return;

        // always update the real dataset
        chart.data.labels = labels;
        chart.data.datasets[0].data = realData;

        // handle the predicted data
        if (predData && predData.length > 0) {
            // extend the labels
            chart.data.labels = [...labels, ...predLabels];

            // create a second dataset for predictions
            const lastRealIndex = realData.length;
            const emptyData = new Array(lastRealIndex).fill(null);

            const predictedDataset = {
                label: "Predicted " + chart.data.datasets[0].label,
                borderColor: chart.data.datasets[0].borderColor,
                data: [...emptyData, ...predData],
                fill: false,
                borderWidth: 2,
                borderDash: [5, 5],
                pointRadius: 0
            };

            // ensure we have exactly two datasets: real + predicted
            chart.data.datasets = [
                chart.data.datasets[0],
                predictedDataset
            ];
        } else {
            // no predictions => keep single dataset
            chart.data.datasets = [chart.data.datasets[0]];
        }

        // update chart styles for dark/light
        if (chart.options.scales.x) {
            chart.options.scales.x.ticks.color = getTextColor();
            chart.options.scales.x.grid.color  = getGridColor();
        }
        if (chart.options.scales.y) {
            chart.options.scales.y.ticks.color = getTextColor();
            chart.options.scales.y.grid.color  = getGridColor();
        }
        if (chart.options.plugins?.legend?.labels) {
            chart.options.plugins.legend.labels.color = getTextColor();
        }

        chart.update();
    }
</script>

<!-- Layout with 5 canvas elements. Your design may differ. -->
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

<style>
    /* You can keep chart-container or any chart styles here, or in a page/global style */
    .chart-container {
        width: 100%;
        height: 300px;
        background: var(--card-bg);
        border-radius: 8px;
        padding: 10px;
        box-shadow: 0 4px 8px rgba(0,0,0,0.1);
    }
</style>
