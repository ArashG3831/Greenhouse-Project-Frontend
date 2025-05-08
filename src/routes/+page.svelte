<script>
    import { onMount  } from "svelte";
    import Chart from "chart.js/auto";
    import 'bootstrap/dist/css/bootstrap.min.css';

    let fetchInterval = null;

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

    import ExcelJS from 'exceljs';
    import pkg from 'file-saver';
    const { saveAs } = pkg;


    const NUMERIC_COLUMNS = [
        "temperature",
        "humidity",
        "oxygen_level",
        "co2_level",
        "light_illumination"
    ];

    // Original name => user-friendly header text
    const COLUMN_LABELS = {
        date_time:           "Date/Time",
        temperature:         "Temperature (°C)",
        humidity:            "Humidity (%)",
        oxygen_level:        "O₂ (%)",
        co2_level:           "CO₂ (ppm)",
        light_illumination:  "Light (lx)"
    };

    ////////////////////////////////////////////////////////////////////////////////
    // 2) Convert your sensorData to a new array of rows
    //    Skips 'timestamp'/'formattedTime' and merges them into 'date_time' column
    ////////////////////////////////////////////////////////////////////////////////
    function buildExcelRows(data) {
        return data.map(obj => {
            const dateTimeStr = new Date(obj.timestamp).toLocaleString("en-US", {
                year:  "numeric",
                month: "2-digit",
                day:   "2-digit",
                hour:  "2-digit",
                minute:"2-digit",
                hour12: true
            });

            return {
                date_time:          dateTimeStr,
                temperature:        obj.temperature,
                humidity:           obj.humidity,
                oxygen_level:       obj.oxygen_level,
                co2_level:          obj.co2_level,
                light_illumination: obj.light_illumination
            };
        });
    }

    ////////////////////////////////////////////////////////////////////////////////
    // 3) Build + style the Excel workbook, applying filters and column rename
    ////////////////////////////////////////////////////////////////////////////////
    async function downloadExcel() {
        if (!sensorData || !sensorData.length) {
            console.error("No data available to download.");
            return;
        }

        const excelRows = buildExcelRows(sensorData);

        // Collect the final property names in the order we want them
        // e.g. ["date_time", "group_id", "temperature", ...]
        const finalProps = Object.keys(excelRows[0]);

        // Map those to user-friendly labels
        const headers = finalProps.map(prop => COLUMN_LABELS[prop] ?? prop);
        const colCount = headers.length;

        const workbook = new ExcelJS.Workbook();
        const worksheet = workbook.addWorksheet("Data");

        // --- Title row (row 1) ---
        const titleText = "Greenhouse Environmental Data Overview";
        const titleRowValues = new Array(colCount).fill("");
        titleRowValues[0] = titleText;
        const titleRow = worksheet.addRow(titleRowValues);

        worksheet.mergeCells(1, 1, 1, colCount);

        const titleCell = worksheet.getCell("A1");
        titleCell.font = {
            bold: true,
            size: 18,
            color: { argb: "FFFFFFFF" } // White text
        };
        titleCell.alignment = { horizontal: "center", vertical: "middle" };
        titleCell.fill = {
            type: "pattern",
            pattern: "solid",
            fgColor: { argb: "FF2F5597" } // Dark blue background
        };

        // --- Header row (row 2) ---
        const headerRow = worksheet.addRow(headers);
        headerRow.eachCell((cell) => {
            cell.font = { bold: true, size: 14, color: { argb: "FFFFFFFF" } };
            cell.alignment = { horizontal: "center", vertical: "middle" };
            cell.fill = {
                type: "pattern",
                pattern: "solid",
                fgColor: { argb: "FF4F81BD" } // Lighter dark-blue fill
            };
        });

        // --- Data rows (starting row 3) ---
        const reversedData = excelRows.slice().reverse();
        reversedData.forEach((rowObj) => {
            const rowValues = finalProps.map(prop => rowObj[prop]);
            const row = worksheet.addRow(rowValues);
            row.eachCell(cell => {
                cell.alignment = { horizontal: 'center', vertical: 'middle' };
            });
        });

        // Row striping for data rows
        worksheet.eachRow({ includeEmpty: false }, (row, rowNumber) => {
            // Skip row 1 (title) + row 2 (headers). Start at row 3
            if (rowNumber >= 3 && rowNumber % 2 === 0) {
                row.eachCell(cell => {
                    cell.fill = {
                        type: "pattern",
                        pattern: "solid",
                        fgColor: { argb: "FFCCECFF" } // pastel blue
                    };
                });
            }
        });

        // Numeric formatting
        NUMERIC_COLUMNS.forEach(colName => {
            const colIndex = finalProps.indexOf(colName);
            if (colIndex >= 0) {
                worksheet.getColumn(colIndex + 1).numFmt = "0.00";
            }
        });

        // Auto-fit columns
        const MAX_WIDTH = 50;
        const EXTRA_PADDING = 5;
        finalProps.forEach((prop, colIndex) => {
            let maxLength = headers[colIndex].length;
            excelRows.forEach(row => {
                const val = row[prop] ? row[prop].toString() : "";
                maxLength = Math.max(maxLength, val.length);
            });
            worksheet.getColumn(colIndex + 1).width = Math.min(MAX_WIDTH, maxLength + EXTRA_PADDING);
        });

        // 4) Turn on AutoFilter on the header row (row 2)
        worksheet.autoFilter = {
            from: { row: 2, column: 1 },
            to:   { row: 2, column: colCount }
        };

        // 5) Generate + download
        const buffer = await workbook.xlsx.writeBuffer();
        const blob = new Blob([buffer], { type: "application/octet-stream" });
        const fileNameMapping = {
            "1h": "Greenhouse Data Last Hour.xlsx",
            "24h": "Greenhouse Data Last 24 Hours.xlsx",
            "7d": "Greenhouse Data Last 7 Days.xlsx",
            "30d": "Greenhouse Data Last 30 Days.xlsx",
            "all": "Greenhouse Data All.xlsx"
        };
        const fileName = fileNameMapping[selectedRange] || `Greenhouse Data ${selectedRange}.xlsx`;
        saveAs(blob, fileName);
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

    // Track "Last Updated" and loading state
    let lastUpdated = "Loading...";
    let isLoading = true;
    let lastValidTimestamp = null;
    let lastUpdatedElement;

    // Track "Dispensing" for the +10ml button
    let dispensing = false;  // true for 1 second after pressing +10ml

    // let ip = "http://5.201.140.68:8091";

    let ip = "https://api.arashg.ir"

    let lastRangeFetched = null;

    async function fetchData() {
        try {
            isLoading = true;
            console.log("📡 Checking if data fetch is needed...");

            const shouldAlwaysFetch = selectedRange === "1h" || selectedRange === "24h";
            const isNewRange = lastRangeFetched !== selectedRange;

            if (shouldAlwaysFetch || isNewRange) {
                console.log(`📡 Fetching Data for range: ${selectedRange}`);
                lastRangeFetched = selectedRange;

                const sensorResponse = await fetch(`${ip}/api/get_data?range=${selectedRange}`);
                const sensorJson = await sensorResponse.json();

                if (!sensorJson.data || !Array.isArray(sensorJson.data)) {
                    console.error("❌ Invalid format from backend:", sensorJson);
                    return;
                }

                sensorData = sensorJson.data;

                if (["24h", "7d"].includes(selectedRange)) {
                    const predictionResponse = await fetch(ip + "/api/get_predictions");
                    predictionData = (await predictionResponse.json()).reverse();
                } else {
                    predictionData = [];
                }

                if (sensorData.length === 0) {
                    console.error("❌ API returned empty sensor data");
                    return;
                }

                updateLiveSensorValues(); // Still uses sensorData

                formatTimestamps();
                filterDataForChart();

                if (tempChart) {
                    updateCharts();
                } else {
                    initializeCharts();
                    updateCharts();
                }
            } else {
                console.log(`⚠️ Skipped fetch for range: ${selectedRange}`);
            }

        } catch (error) {
            console.error("❌ Error in fetchData():", error);
        } finally {
            isLoading = false;
        }
    }


    async function fetchLatestOnly() {
        try {
            const response = await fetch(ip + "/api/get_latest");
            const latest = await response.json();

            // Update only the live data and timestamp
            latestTemperature = latest.temperature?.toFixed(2) + "°C" || "N/A";
            latestHumidity = latest.humidity?.toFixed(2) + "%" || "N/A";
            latestOxygen = latest.oxygen_level?.toFixed(2) + "%" || "N/A";
            latestLight = latest.light_illumination?.toFixed(2) + " lx" || "N/A";

            const parsedDate = new Date(latest.timestamp);
            const formatter = new Intl.DateTimeFormat("en-US", {
                timeZone: "Asia/Tehran",
                year: "numeric", month: "2-digit", day: "2-digit",
                hour: "2-digit", minute: "2-digit", second: "2-digit",
                hour12: false
            });
            lastUpdated = formatter.format(parsedDate);

            if (lastUpdatedElement) {
                lastUpdatedElement.classList.remove("updated");
                void lastUpdatedElement.offsetWidth;
                lastUpdatedElement.classList.add("updated");
            }
        } catch (err) {
            console.error("❌ Failed to fetch latest sensor data:", err);
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

    let fanMode = null;
    let fanIsRunning = false;
    let waterMode = null;
    let waterControl = { water_mode: "auto", last_water_dispense: null };
    let waterDispensedAgo = "Loading...";
    let waterDispenseActive;

    async function updateFanMode(mode) {
        if (!isLoggedIn) {
            console.error("Access Denied: You are not authenticated to change fan mode.");
            // For normal users, clicking does nothing (state remains unchanged)
            return;
        }
        try {
            const response = await fetch(ip + "/api/set_control_state/", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ fan_mode: mode })
            });
            const data = await response.json();
            fanMode = data.fan_mode;
            fanIsRunning = data.fan_is_running;
        } catch (error) {
            console.error("❌ Error updating fan control:", error);
        }
    }

    async function updateWaterMode(mode) {
        if (!isLoggedIn) {
            console.error("Access Denied: You are not authenticated to change water mode.");
            // Normal users cannot update the state via this function.
            return;
        }
        try {
            const response = await fetch(ip + "/api/set_control_state/", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ water_mode: mode })
            });
            const data = await response.json();
            waterMode = data.water_mode;
            waterControl = data;
            updateTimeDiff();
        } catch (error) {
            console.error("❌ Error updating water control:", error);
        }
    }

    async function handleWaterDispense() {
        if (!isLoggedIn) {
            console.error("Access Denied: You are not authenticated to dispense water.");
            // Normal users will see no change when clicking.
            return;
        }
        try {
            await fetch(ip + "/api/set_control_state/", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ water_mode: "+10ml" })
            });
            // Instead of forcing auto mode, just refresh the control state
            await fetchControlState();
        } catch (err) {
            console.error("❌ Error dispensing water:", err);
        }
    }

    let waterUpdatedElement; // Bind this to the "Last watered" element

    function updateTimeDiff() {
        if (!waterControl.last_water_dispense) {
            waterDispensedAgo = "Never";
        } else {
            const lastTime = new Date(waterControl.last_water_dispense);
            const diffSec = Math.floor((Date.now() - lastTime.getTime()) / 1000);
            if (diffSec < 0) {
                waterDispensedAgo = "Just now";
            } else if (diffSec < 60) {
                waterDispensedAgo = diffSec === 1 ? "1 second ago" : `${diffSec} seconds ago`;
            } else if (diffSec < 3600) {
                const minutes = Math.floor(diffSec / 60);
                waterDispensedAgo = minutes === 1 ? "1 minute ago" : `${minutes} minutes ago`;
            } else {
                const hours = Math.floor(diffSec / 3600);
                waterDispensedAgo = hours === 1 ? "1 hour ago" : `${hours} hours ago`;
            }
        }
        // Trigger the fade-in on the dynamic part only:
        if (waterUpdatedElement) {
            waterUpdatedElement.classList.remove("updated");
            void waterUpdatedElement.offsetWidth; // force reflow
            waterUpdatedElement.classList.add("updated");
        }
    }


    // Example function to fetch control state (ensure waterControl gets updated)
    async function fetchControlState() {
        try {
            const response = await fetch(ip + "/api/get_control_state/");
            const data = await response.json();
            waterControl = data;
            waterMode = data.water_mode;
            // Assume the backend returns fan control state as well:
            fanMode = data.fan_mode;
            fanIsRunning = data.fan_is_running;
            updateTimeDiff();
        } catch (err) {
            console.error("Error fetching control state", err);
        }
    }


    function filterDataForChart() {
        let step = 1;
        if (selectedRange === "1h") {
            step = 1;
        } else if (selectedRange === "7d") {
            step = 1;
        } else if (selectedRange === "24h") {
            step = 1;
        } else if (selectedRange === "30d") {
            step = 1;
        } else if (selectedRange === "all") {
            step = isMobile ? 6 : 1;
        }
        sensorData = sensorData.filter((_, index) => index % step === 0);
    }

    function formatTimestamps() {
        const formatterTime = new Intl.DateTimeFormat("en-US", {
            timeZone: "Asia/Tehran",
            hour: '2-digit',
            minute: '2-digit'
        });

        const formatterDateHour = new Intl.DateTimeFormat("en-US", {
            timeZone: "Asia/Tehran",
            weekday: 'short',
            hour: '2-digit'
        });

        const formatterMonthDay = new Intl.DateTimeFormat("en-US", {
            timeZone: "Asia/Tehran",
            month: 'short',
            day: 'numeric'
        });

        sensorData.forEach(d => {
            const date = new Date(d.timestamp);

            if (selectedRange === "1h" || selectedRange === "24h") {
                d.formattedTime = formatterTime.format(date);
            } else if (selectedRange === "7d") {
                d.formattedTime = formatterDateHour.format(date);
            } else if (selectedRange === "30d") {
                d.formattedTime = formatterMonthDay.format(date);
            } else if (selectedRange === "all") {
                const tehranWeek = getWeekNumberInTehran(date);
                d.formattedTime = `Week ${tehranWeek}`;
            }
        });

        if (selectedRange === "all") {
            sensorData.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
        }
    }


    function getWeekNumberInTehran(date) {
        const tehranDate = new Date(date.toLocaleString("en-US", { timeZone: "Asia/Tehran" }));
        const start = new Date(tehranDate.getFullYear(), 0, 1);
        const diff = tehranDate - start;
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
        // Always update the first (real) dataset
        chart.data.labels = labels;
        chart.data.datasets[0].data = data;

        // If we do have predictions, create the second dataset
        if (predData && predData.length > 0) {
            const lastRealIndex = data.length;
            const emptyData = new Array(lastRealIndex).fill(null);

            // Rebuild the entire labels array to include predLabels
            chart.data.labels = [...labels, ...predLabels];

            // Construct the second dataset
            const predictedDataset = {
                label: `Predicted ${chart.data.datasets[0].label}`,
                borderColor: chart.data.datasets[0].borderColor,
                data: [...emptyData, ...predData],
                fill: false,
                borderWidth: 2,
                borderDash: [5, 5],
                pointRadius: 0,
                pointHitRadius: 10,
                pointHoverRadius: 5
            };

            // Replace datasets with two: real + predicted
            chart.data.datasets = [
                chart.data.datasets[0],
                predictedDataset
            ];
        } else {
            // No prediction data => remove the second dataset
            chart.data.datasets = [chart.data.datasets[0]];
        }

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
                        borderWidth: 2,
                        pointRadius: 0,
                        pointHitRadius: 10,
                        pointHoverRadius: 5,
                        tension: 0.4
                    },
                    {
                        label: "Predicted " + label,
                        borderColor: color,
                        data: [],
                        fill: false,
                        borderWidth: 2,
                        borderDash: [5, 5],
                        pointRadius: 0,
                        pointHitRadius: 10,
                        pointHoverRadius: 5,
                        tension: 0.4
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                devicePixelRatio: 4, // or even higher, e.g. 3, if your device supports it
                elements: {
                    point: {
                        radius: 0,
                        hitRadius: 10,
                        hoverRadius: 5
                    }
                },
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
                    tooltip: {
                        enabled: true
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
        dispatch('change', opt.value);
        isOpen = false;

        // Always fetch once immediately
        fetchData();

        // Clear existing interval (if any)
        if (fetchInterval) {
            clearInterval(fetchInterval);
            fetchInterval = null;
        }

        // Only start polling if selectedRange is short-term
        if (selectedRange === "1h" || selectedRange === "24h") {
            fetchInterval = setInterval(() => {
                fetchData();
                fetchControlState();
            }, 5000);
        }
    }



    function handleClickOutside(event) {
        const dropdown = document.querySelector(".custom-dropdown");
        if (dropdown && !dropdown.contains(event.target)) {
            isOpen = false;
        }
    }

    let outsideTempNow = "Loading...";
    let outsideWindNow = "Loading...";
    let outsideTempTomorrow = "Loading...";
    let outsideWindTomorrow = "Loading...";

    let currentWeatherCode = null;
    let forecastWeatherCode = null;

    // Mapping from Open-Meteo weather codes to OpenWeatherMap icon URLs.
    // (Adjust these mappings to suit your needs.)
    function getWeatherIconUrl(code) {
        const mapping = {
            0: "https://openweathermap.org/img/wn/01d@2x.png",  // Clear sky
            1: "https://openweathermap.org/img/wn/02d@2x.png",  // Mainly clear
            2: "https://openweathermap.org/img/wn/03d@2x.png",  // Partly cloudy
            3: "https://openweathermap.org/img/wn/04d@2x.png",  // Overcast
            45: "https://openweathermap.org/img/wn/50d@2x.png", // Fog
            48: "https://openweathermap.org/img/wn/50d@2x.png", // Depositing rime fog
            51: "https://openweathermap.org/img/wn/09d@2x.png", // Drizzle: Light
            53: "https://openweathermap.org/img/wn/09d@2x.png", // Drizzle: Moderate
            55: "https://openweathermap.org/img/wn/09d@2x.png", // Drizzle: Dense intensity
            61: "https://openweathermap.org/img/wn/10d@2x.png", // Rain: Slight
            63: "https://openweathermap.org/img/wn/10d@2x.png", // Rain: Moderate
            65: "https://openweathermap.org/img/wn/10d@2x.png", // Rain: Heavy intensity
            71: "https://openweathermap.org/img/wn/13d@2x.png", // Snow fall: Slight
            73: "https://openweathermap.org/img/wn/13d@2x.png", // Snow fall: Moderate
            75: "https://openweathermap.org/img/wn/13d@2x.png", // Snow fall: Heavy
            80: "https://openweathermap.org/img/wn/10d@2x.png", // Rain showers: Slight
            81: "https://openweathermap.org/img/wn/10d@2x.png", // Rain showers: Moderate
            82: "https://openweathermap.org/img/wn/10d@2x.png", // Rain showers: Violent
            95: "https://openweathermap.org/img/wn/11d@2x.png", // Thunderstorm: Slight/moderate
            96: "https://openweathermap.org/img/wn/11d@2x.png", // Thunderstorm with slight hail
            99: "https://openweathermap.org/img/wn/11d@2x.png"  // Thunderstorm with heavy hail
        };
        return mapping[code] || "https://openweathermap.org/img/wn/50d@2x.png";
    }

    // Fetch outside weather using Open-Meteo
    async function fetchOutsideWeather() {
        try {
            // Fetch current weather for Tehran
            const currentResponse = await fetch(
                "https://api.open-meteo.com/v1/forecast?latitude=35.6892&longitude=51.3890&current_weather=true&timezone=auto"
            );
            const currentData = await currentResponse.json();
            if (!currentData.current_weather) {
                throw new Error("No current weather data available");
            }
            outsideTempNow = currentData.current_weather.temperature.toFixed(1);
            outsideWindNow = currentData.current_weather.windspeed.toFixed(1);
            currentWeatherCode = currentData.current_weather.weathercode;

            // Compute tomorrow's date in YYYY-MM-DD format
            const today = new Date();
            const tomorrow = new Date(today);
            tomorrow.setDate(today.getDate() + 1);
            const yyyy = tomorrow.getFullYear();
            const mm = String(tomorrow.getMonth() + 1).padStart(2, '0');
            const dd = String(tomorrow.getDate()).padStart(2, '0');
            const tomorrowStr = `${yyyy}-${mm}-${dd}`;

            // Fetch daily forecast for tomorrow including the weather code
            const forecastResponse = await fetch(
                `https://api.open-meteo.com/v1/forecast?latitude=35.6892&longitude=51.3890&daily=temperature_2m_max,wind_speed_10m_max,weathercode&timezone=auto&start_date=${tomorrowStr}&end_date=${tomorrowStr}`
            );
            const forecastData = await forecastResponse.json();
            if (!forecastData.daily) {
                throw new Error("No forecast data available");
            }
            outsideTempTomorrow = forecastData.daily.temperature_2m_max[0].toFixed(1);
            outsideWindTomorrow = forecastData.daily.wind_speed_10m_max[0].toFixed(1);
            forecastWeatherCode = forecastData.daily.weathercode[0];
        } catch (error) {
            console.error("❌ Error fetching outside weather:", error);
        }
    }

    // Set your hard-to-guess secret key here
    const secretKey = "9975afad-dea0-477e-a5a3-6586d8da3f8a"; // Replace with your chosen token
    let isLoggedIn;
    // Function to get the stored token from localStorage
    function getStoredToken() {
        return localStorage.getItem('loginToken');
    }

    onMount(() => {
        const token = getStoredToken();
        if (token && token === secretKey) {
            console.log("Browser recognized and token valid. You are authenticated.");
            isLoggedIn = true;
        } else {
            console.error("No valid token found in localStorage. Access denied.");
            isLoggedIn = false;
        }

        // Initial fetches
        fetchData();
        fetchOutsideWeather();
        fetchControlState();
        fetchLatestOnly()

        // Periodic fetchData only for short-term ranges
        if (selectedRange === "1h" || selectedRange === "24h") {
            fetchInterval = setInterval(() => {
                fetchData();
            }, 5000);
        }

        // 🔁 Control state must be updated every second, always
        setInterval(() => {
            fetchControlState();
        }, 3000);

        // Other initial setup
        isMobile = window.innerWidth < 768;

        const savedTheme = getCookie("theme");
        if (savedTheme) {
            theme = savedTheme;
        }

        updateWaterMode();
        updateFanMode();

        initializeCharts();

        document.addEventListener("click", handleClickOutside);

        // Weather update every 60s
        setInterval(() => {
            fetchOutsideWeather();
        }, 60000);

        setInterval(fetchLatestOnly, 5000);

    });


</script>

<svelte:head>
    <title>Greenhouse Dahboard - Real-time Environmental Monitoring</title>  <!-- <- Change this line -->
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
                ☀️ Switch to Light Theme
            {:else}
                🌙 Switch to Dark Theme
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
            <!-- Use align-items-stretch so both columns fill the same vertical height -->
            <div class="row gx-4 gy-4 align-items-stretch">

                <!-- LEFT COLUMN (Live Data) -->
                <div class="col-md-7 d-flex flex-column">
                    <!-- Heading row (no flex-grow, just the heading) -->
                    <div class="d-flex justify-content-between align-items-center mb-3">
                        <h2 class="section-title m-0">Live Data</h2>
                        <!-- Mobile Theme Toggle -->
                        <button style="font-size: 16px; border-radius: 64px"
                                on:click={toggleTheme}
                                class="theme-toggle-mobile d-block d-md-none m-0">
                            {#if theme === 'dark'}
                                ☀️ Switch to Light Theme
                            {:else}
                                🌙 Switch to Dark Theme
                            {/if}
                        </button>
                    </div>

                    <!-- Container for the sensor cards. Use flex-grow-1 so it fills leftover space -->
                    <div class="row row-cols-2 gx-3 gy-3 flex-grow-1">
                        <!-- Each .col is also d-flex so the card can fill it -->
                        <div class="col d-flex">
                            <div class="p-0 sensor-card text-center flex-fill">
                                <h3>Temperature</h3>
                                <p class="fs-4 text-danger">{latestTemperature}</p>
                            </div>
                        </div>
                        <div class="col d-flex">
                            <div class="sensor-card text-center flex-fill">
                                <h3>Humidity</h3>
                                <p class="fs-4 text-primary">{latestHumidity}</p>
                            </div>
                        </div>
                        <div class="col d-flex">
                            <div class="sensor-card text-center flex-fill">
                                <h3>Oxygen Level</h3>
                                <p class="fs-4 text-success">{latestOxygen}</p>
                            </div>
                        </div>
                        <div class="col d-flex">
                            <div class="sensor-card text-center flex-fill">
                                <h3>Light Intensity</h3>
                                <p class="fs-4 text-warning">{latestLight}</p>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- RIGHT COLUMN (Controls) -->
                <div class="col-md-5 d-flex flex-column">
                    <!-- Heading row -->
                    <div class="d-flex justify-content-between align-items-center mb-3">
                        <h2 class="section-title m-0">Controls</h2>
                    </div>

                    <!-- Fan Control Card -->
                    <div class="sensor-card text-center mb-3 control-card-container">
                        <h3 class="text-center">
                            <img src="/fan-blades-icon.svg" alt="Fan Icon" class="me-1 mb-1 {fanIsRunning ? 'spinning-icon' : ''} {theme === 'dark' ? 'inverted-svg' : ''}" style="max-width: 28px;">
                            Fan Control
                        </h3>
                        <div class="btn-group my-2">
                            <button class="p-0 align-items-center d-flex btn btn-outline-success {fanMode === 'auto' ? 'active' : ''}"
                                    on:click={() => updateFanMode('auto')}
                                    style="width: 84px; height: 38px">
                                {#if fanMode === 'auto' || theme === 'dark'}
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
                        {#if !isLoggedIn}
                            <div class="control-overlay"></div>
                        {/if}
                    </div>


                    <!-- Water Control Card -->
                    <div class="sensor-card text-center control-card-container">
                        <h3>Water Control</h3>
                        <p class="last-watered mb-2">
                            Last watered:
                            <span bind:this={waterUpdatedElement} class="water-time">{waterDispensedAgo}</span>
                        </p>
                        <div class="btn-group my-2">
                            <button class="p-0 align-items-center d-flex btn btn-outline-success {waterMode === 'auto' ? 'active' : ''}"
                                    on:click={() => updateWaterMode('auto')}
                                    style="width: 84px; height: 38px">
                                {#if waterMode === 'auto' || theme === 'dark'}
                                    <img class="mx-1" src="/smart.png" alt="smart icon" style="border-radius:16px" width="28" height="28"/>
                                {:else}
                                    <img class="mx-1" src="/smart2.png" alt="smart icon" style="border-radius:16px" width="28" height="28"/>
                                {/if}
                                Auto
                            </button>
                            <button class="p-0 water-btn btn btn-outline-info"
                                    on:click={handleWaterDispense}
                                    style="width: 84px; height: 38px">
                                +10ml
                            </button>
                            <button class="btn btn-outline-danger {waterMode === 'off' ? 'active' : ''}"
                                    on:click={() => updateWaterMode('off')}
                                    style="width: 84px; height: 38px">
                                Off
                            </button>
                        </div>
                        {#if !isLoggedIn}
                            <div class="control-overlay"></div>
                        {/if}
                    </div>

                </div>
            </div>

            <!-- Outside Weather Section -->
<!--            <div class="row g-4 mt-md-5 mt-4">-->
<!--                <h2 class="section-title mb-4">Outside Weather</h2>-->
<!--                <div class="" style="display: flex; justify-content: center; align-items: center;">-->
<!--                    &lt;!&ndash; Current Weather (Now) &ndash;&gt;-->
<!--                    <div class="mx-2">-->
<!--                        <div class="sensor-card weather-card text-center p-3">-->
<!--                            <h4 class="fw-bold mb-2">Now</h4>-->
<!--                            <div class="weather-icon mb-3">-->
<!--                                <img src="{getWeatherIconUrl(currentWeatherCode)}" alt="Current Weather Icon" style="width:60px; height:60px;" />-->
<!--                            </div>-->
<!--                            <p class="fs-5 mb-1 text-info">{outsideTempNow}°C</p>-->
<!--                            <p class="fs-6 text-secondary">Wind {outsideWindNow} m/s</p>-->
<!--                        </div>-->
<!--                    </div>-->
<!--                    &lt;!&ndash; Tomorrow's Forecast &ndash;&gt;-->
<!--                    <div class="mx-2">-->
<!--                        <div class="sensor-card weather-card text-center p-3">-->
<!--                            <h4 class="fw-bold mb-2">Tomorrow</h4>-->
<!--                            <div class="weather-icon mb-3">-->
<!--                                <img src="{getWeatherIconUrl(forecastWeatherCode)}" alt="Tomorrow Weather Icon" style="width:60px; height:60px;" />-->
<!--                            </div>-->
<!--                            <p class="fs-5 mb-1 text-warning">{outsideTempTomorrow}°C</p>-->
<!--                            <p class="fs-6 text-secondary">Wind {outsideWindTomorrow} m/s</p>-->
<!--                        </div>-->
<!--                    </div>-->
<!--                </div>-->
<!--            </div>-->

<!--             Optional custom styles to enforce a max width and center the cards -->

<!--            <div class="row g-4 mt-md-5 mt-4 mt-5 text-center">-->
<!--                <div class="col-6 sensor-card" style="">-->

<!--                </div>-->
<!--                <div class="col-6 sensor-card" style="">-->

<!--                </div>-->
<!--            </div>-->
            <h2 class="section-title mb-4 mt-md-5 mt-4">
                Official Weather Forecast
                <br>
                <small class="powered-text" style="font-size: 0.7em;">
                    Powered by the Open-Meteo API
                </small>
            </h2>

            <div class="row row-cols-2 gx-3 gy-3 flex-grow-1 text-center justify-content-center">
                <div class="col d-flex responsive-width">
                    <div class="sensor-card text-center flex-fill">
                        <h4 class="fw-bold mb-2">Now</h4>
                        <div class="weather-icon mb-3">
                            <img src="{getWeatherIconUrl(currentWeatherCode)}" alt="Current Weather Icon" style="width:60px; height:60px;" />
                        </div>
                        <p class="fs-5 mb-1 text-info">{outsideTempNow}°C</p>
                        <p class="fs-6 text-secondary">Wind {outsideWindNow} m/s</p>
                    </div>
                </div>
                <div class="col d-flex responsive-width">
                    <div class="sensor-card text-center flex-fill">
                        <h4 class="fw-bold mb-2">Tomorrow</h4>
                        <div class="weather-icon mb-3">
                            <img src="{getWeatherIconUrl(forecastWeatherCode)}" alt="Tomorrow Weather Icon" style="width:60px; height:60px;" />
                        </div>
                        <p class="fs-5 mb-1 text-warning">{outsideTempTomorrow}°C</p>
                        <p class="fs-6 text-secondary">Wind {outsideWindTomorrow} m/s</p>
                    </div>
                </div>

            </div>





        </div>


        <!-- Charts -->
        <div class="mt-md-5 mt-4">
            <h2 class="section-title mb-3">Sensor Data Trends</h2>
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

            <div class="text-center mt-md-5 mt-4">
                <button class="btn-custom-excel" on:click={downloadExcel}>
                    <img class="excel-icon" src="/excel.webp" alt="Excel icon" />
                    Download Data as Excel
                </button>
            </div>




        </div>
    </div>

    <!-- Footer -->
    <footer class="footer p-md-5 p-4 mb-5 mt-md-5 mt-4" style="padding-bottom: 4px !important">
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
    /* In your <style> block or external stylesheet: */

    /* Set up the button to use flex so icon + text line up well */
    .btn-custom-excel {
        display: inline-flex;         /* keep it only as wide as needed */
        align-items: center;          /* center icon and text vertically */
        justify-content: center;      /* optional if you want the text centered */

        background-color: #217346;    /* more Excel-like green */
        color: #fff;
        border: none;
        border-radius: 6px;
        padding: 0.5rem 1rem;
        font-size: 1rem;
        font-weight: 500;             /* slightly bolder text */
        cursor: pointer;
        transition: background-color 0.2s ease;

        /* Optionally give it a slight shadow: */
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.3);
    }

    /* Darker hover state */
    .btn-custom-excel:hover {
        background-color: #185c33;   /* a bit darker than #217346 */
    }

    /* Icon style */
    .excel-icon {
        width: 32px;
        height: 32px;
        margin-right: 0.6rem;

        /* Smooth transition for hover effect */
        transition: transform 0.2s, filter 0.2s;
    }

    /* When hovering the button, enlarge and brighten the icon a bit */
    .btn-custom-excel:hover .excel-icon {
        /*transform: scale(1.1);            !* slight scale‐up *!*/
        filter: brightness(1.2);          /* makes it pop more */
        /* or you could add a drop shadow: filter: drop-shadow(0 2px 2px rgba(0,0,0,0.3)); */
    }



    .control-card-container {
        position: relative;
    }

    .control-overlay {
        position: absolute;
        border-radius: 10px;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background-color: rgba(128, 128, 128, 0.5); /* grey transparent overlay */
        z-index: 10;
    }

    .inverted-svg {
        -webkit-filter: invert(1);
        filter: invert(1);
    }

    .powered-text {
        font-size: 0.7em;
        /* fallback color from Bootstrap text-muted if needed */
        color: var(--bs-text-muted);
    }

    .light .powered-text {
        color: #6c757d; /* white in light mode */
    }

    .dark .powered-text {
        color: #d3d3d3; /* light grey in dark mode */
    }

    .responsive-width {
        /* For large screens (above 1200px) */
        max-width: 20%;
    }

    @media (max-width: 1200px) {
        /* For medium screens (below 1200px) */
        .responsive-width {
            max-width: 30%;
        }
    }

    @media (max-width: 768px) {
        /* For small screens (below 768px) */
        .responsive-width {
            max-width: 100%;
        }
    }


    .sensor-card.weather-card {
        max-width: 400px;
        margin-left: auto;
        margin-right: auto;
    }
    /* Keep sensor-card styling, then narrow them a bit for weather */
    .weather-card {
        min-width: 200px; /* or 280px, etc. */
        margin: 0 auto;   /* center horizontally */
    }

    .outside-weather-card {
        background: linear-gradient(135deg, rgba(255,255,255, 0.05) 0%, rgba(255,255,255, 0.02) 100%);
        border-radius: 10px;
        box-shadow: 0 4px 10px rgba(0,0,0,0.1);
        overflow: hidden;
    }
    .weather-icon img {
        filter: drop-shadow(0 2px 2px rgba(0,0,0,0.2));
    }
    @media (max-width: 767px) {
        .outside-weather-container .col-md-6 {
            margin-bottom: 1.5rem;
        }
    }

    .last-watered {
        font-size: 18px;
        /* No animation on the entire element */
    }
    .water-time.updated {
        /*animation: fadeIn 1s;*/
    }
    @keyframes fadeIn {
        from { opacity: 0; }
        to   { opacity: 1; }
    }
    .spinning-icon {
        animation: spin 0.5s linear infinite;
        /* can help reduce flicker or pixelation in some cases */
        will-change: transform;
        backface-visibility: hidden;
    }

    @keyframes spin {
        0%   { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
    }


    .water-btn.dispensing-active {
        animation: waterFlash 2s ease;
    }

    @keyframes waterFlash {
        0%   { background-color: #007a7a; }
        50%  { background-color: #28a745; }
        100% { background-color: #007a7a; }
    }

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
        /*min-height: 120px;*/
        align-content: center;
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
        padding: 8px 10px;
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
