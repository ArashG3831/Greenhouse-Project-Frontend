<script>
    import ExcelJS from 'exceljs';
    import pkg from 'file-saver';
    const { saveAs } = pkg;

    export let sensorData = [];
    export let selectedRange = "7d";

    const NUMERIC_COLUMNS = [
        "temperature", "humidity", "oxygen_level", "co2_level", "light_illumination"
    ];

    const COLUMN_LABELS = {
        date_time:           "Date/Time",
        temperature:         "Temperature (°C)",
        humidity:            "Humidity (%)",
        oxygen_level:        "O₂ (%)",
        co2_level:           "CO₂ (ppm)",
        light_illumination:  "Light (lx)"
    };

    function buildExcelRows(data) {
        return data.map(obj => {
            const dateTimeStr = new Date(obj.timestamp).toLocaleString("en-US", {
                year: "numeric", month: "2-digit", day: "2-digit",
                hour: "2-digit", minute: "2-digit", hour12: true
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

    async function downloadExcel() {
        if (!sensorData || !sensorData.length) {
            console.error("No data available to download.");
            return;
        }

        const excelRows = buildExcelRows(sensorData);
        const finalProps = Object.keys(excelRows[0]);
        const headers = finalProps.map(prop => COLUMN_LABELS[prop] ?? prop);

        const workbook = new ExcelJS.Workbook();
        const worksheet = workbook.addWorksheet("Data");

        const colCount = headers.length;

        const titleRowValues = new Array(colCount).fill("");
        titleRowValues[0] = "Greenhouse Environmental Data Overview";
        const titleRow = worksheet.addRow(titleRowValues);
        worksheet.mergeCells(1, 1, 1, colCount);
        const titleCell = worksheet.getCell("A1");
        titleCell.font = { bold: true, size: 18, color: { argb: "FFFFFFFF" } };
        titleCell.alignment = { horizontal: "center", vertical: "middle" };
        titleCell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF2F5597" } };

        const headerRow = worksheet.addRow(headers);
        headerRow.eachCell((cell) => {
            cell.font = { bold: true, size: 14, color: { argb: "FFFFFFFF" } };
            cell.alignment = { horizontal: "center", vertical: "middle" };
            cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF4F81BD" } };
        });

        const reversedData = excelRows.slice().reverse();
        reversedData.forEach(rowObj => {
            const rowValues = finalProps.map(prop => rowObj[prop]);
            const row = worksheet.addRow(rowValues);
            row.eachCell(cell => {
                cell.alignment = { horizontal: 'center', vertical: 'middle' };
            });
        });

        worksheet.eachRow({ includeEmpty: false }, (row, rowNumber) => {
            if (rowNumber >= 3 && rowNumber % 2 === 0) {
                row.eachCell(cell => {
                    cell.fill = {
                        type: "pattern",
                        pattern: "solid",
                        fgColor: { argb: "FFCCECFF" }
                    };
                });
            }
        });

        NUMERIC_COLUMNS.forEach(colName => {
            const colIndex = finalProps.indexOf(colName);
            if (colIndex >= 0) {
                worksheet.getColumn(colIndex + 1).numFmt = "0.00";
            }
        });

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

        worksheet.autoFilter = {
            from: { row: 2, column: 1 },
            to: { row: 2, column: colCount }
        };

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
</script>

<button class="btn-custom-excel" on:click={downloadExcel}>
    <img class="excel-icon" src="/excel.webp" alt="Excel icon" />
    Download Data as Excel
</button>

<style>
    .btn-custom-excel {
        display: flex;
        align-items: center;
        justify-content: flex-start;
        text-align: left;
        gap: 0.6rem;

        background-color: #217346;
        color: #fff;
        border: none;
        border-radius: 6px;
        padding: 0.5rem 1rem;
        font-size: 1rem;
        font-weight: 500;
        cursor: pointer;
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.3);
        min-width: 250px;

        transition: background-color 0.2s ease;
    }

    .btn-custom-excel:hover {
        background-color: #185c33;
    }

    .excel-icon {
        width: 32px;
        height: 32px;
        transition: transform 0.2s, filter 0.2s;
    }

    .btn-custom-excel:hover .excel-icon {
        filter: brightness(1.2);
    }
</style>
