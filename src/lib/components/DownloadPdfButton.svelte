<script>
    export let sensorData = [];
    export let selectedRange = "7d";

    const COLUMN_LABELS = {
        date_time:           "Date/Time",
        temperature:         "Temperature (°C)",
        humidity:            "Humidity (%)",
        oxygen_level:        "O₂ (%)",
        co2_level:           "CO₂ (ppm)",
        light_illumination:  "Light (lx)"
    };

    function buildPdfRows(data) {
        return data.map(obj => {
            const dateTimeStr = new Date(obj.timestamp).toLocaleString("en-US", {
                year: "numeric", month: "2-digit", day: "2-digit",
                hour: "2-digit", minute: "2-digit", hour12: true
            });

            return [
                dateTimeStr,
                obj.temperature?.toFixed(2) ?? "",
                obj.humidity?.toFixed(2) ?? "",
                obj.oxygen_level?.toFixed(2) ?? "",
                obj.co2_level?.toFixed(2) ?? "",
                obj.light_illumination?.toFixed(2) ?? ""
            ];
        });
    }

    async function downloadPdf() {
        if (!sensorData || sensorData.length === 0) {
            console.error("No data available to download.");
            return;
        }

        // 🧠 dynamically import pdfmake only on client
        const pdfMakeModule = await import("pdfmake/build/pdfmake");
        const pdfFonts = await import("pdfmake/build/vfs_fonts");
        pdfMakeModule.default.vfs = pdfFonts.default.pdfMake.vfs;

        const headers = Object.values(COLUMN_LABELS);
        const rows = buildPdfRows(sensorData);
        const body = [headers, ...rows];

        const docDefinition = {
            content: [
                {
                    text: 'Greenhouse Environmental Data Overview',
                    style: 'title',
                    margin: [0, 0, 0, 10]
                },
                {
                    table: {
                        headerRows: 1,
                        widths: ['*', '*', '*', '*', '*', '*'],
                        body: body
                    },
                    layout: {
                        fillColor: function (rowIndex) {
                            return rowIndex === 0
                                ? '#4F81BD'
                                : rowIndex % 2 === 0
                                    ? '#DDEEFF'
                                    : null;
                        },
                        hLineWidth: () => 0.5,
                        vLineWidth: () => 0.5,
                        hLineColor: () => '#aaa',
                        vLineColor: () => '#aaa'
                    }
                }
            ],
            styles: {
                title: {
                    fontSize: 16,
                    bold: true,
                    alignment: 'center',
                    color: '#2F5597'
                }
            },
            pageOrientation: 'landscape',
            pageSize: 'A4'
        };

        pdfMakeModule.default.createPdf(docDefinition).download(`Greenhouse Data ${selectedRange}.pdf`);
    }
</script>

<button class="btn-custom-pdf" on:click={downloadPdf}>
    <img class="pdf-icon" style="text-align: start" src="/Adobe-Acrobat-Reader-icon.svg" alt="PDF icon" />
    Download Data as PDF
</button>

<style>
    .btn-custom-pdf {
        display: flex;
        align-items: center;
        justify-content: flex-start;
        text-align: left;
        gap: 0.6rem;

        background-color: #b91c1c;
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

    .btn-custom-pdf:hover {
        background-color: #8c1616;
    }

    .pdf-icon {
        width: 28px;
        height: 28px;
        padding: 1px;
        filter: brightness(1.2); /* 20% brighter */
    }

    .btn-custom-pdf:hover .pdf-icon {
        filter: brightness(1.4);
    }
</style>
