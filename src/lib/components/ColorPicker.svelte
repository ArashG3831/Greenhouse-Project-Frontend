<!--  src/lib/components/ColorPicker.svelte  -->
<script lang="ts">
    import { onMount, onDestroy, tick, createEventDispatcher } from 'svelte';
    import { browser } from '$app/environment';

    // ---------------- API ----------------
    export let value = '#ff0000';              // initial colour (hex or rgb string)
    const dispatch  = createEventDispatcher(); // bubble up every change

    // ---------------- internal state -----
    let isOpen     = false;
    let isRgbInput = false;        // false = HEX mode   true = RGB mode
    let inputValue = value;        // what the user types in the field

    let containerRef : HTMLDivElement;
    let pickerRef    : HTMLDivElement;
    let iroLib       ;               // the iro.js module
    let picker       ;               // iro instance

    /* ---------- helpers -------------------------------------------------- */
    function emit() {
        dispatch('change', value);   // parent uses on:change
    }

    /** User changed the <input> manually ---------------------------------- */
    function onInputChange() {
        const v = inputValue.trim();

        /* HEX --------- */
        if (!isRgbInput) {
            if (/^#?[0-9A-Fa-f]{6}$/.test(v)) {
                value = v.startsWith('#') ? v : '#'+v;
                emit();
                if (picker) picker.color.hexString = value;
            }
        }
        /* RGB --------- */
        else {
            const parts = v.split(',').map(x => +x.trim());
            if (
                parts.length === 3 &&
                parts.every(n => Number.isInteger(n) && n>=0 && n<=255)
            ) {
                value = `rgb(${parts.join(',')})`;
                emit();
                if (picker) picker.color.rgb = { r:parts[0], g:parts[1], b:parts[2] };
            }
        }
    }

    /** Open the little popup ------------------------------------------------ */
    async function openPicker(e:MouseEvent) {
        e.stopPropagation();
        if (isOpen) return;
        isOpen = true;
        await tick();

        if (!picker && iroLib && pickerRef) {
            picker = new iroLib.ColorPicker(pickerRef, {
                width : 200,
                color : value,
                layout: [
                    { component: iroLib.ui.Wheel },
                    { component: iroLib.ui.Slider, options:{ sliderType:'value' } }
                ]
            });

            picker.on('color:change', c => {
                value      = c.hexString;
                inputValue = isRgbInput
                    ? `${c.rgb.r},${c.rgb.g},${c.rgb.b}`
                    : c.hexString;
                emit();
            });
        }
    }

    /** Close when clicking outside ----------------------------------------- */
    function handleClickOutside(e:MouseEvent) {
        if (containerRef && !containerRef.contains(e.target as Node)) {
            isOpen && (isOpen = false);
        }
    }

    /* ---------------- lifecycle ------------------------------------------ */
    onMount(async () => {
        if (!browser) return;
        const mod = await import('@jaames/iro');
        iroLib = mod.default;
        document.addEventListener('click', handleClickOutside);
    });

    onDestroy(() => {
        if (!browser) return;
        document.removeEventListener('click', handleClickOutside);
        picker && picker.destroy();
    });
</script>

<!-- ======================== MARK-UP ===================================== -->
<div class="color-picker" bind:this={containerRef}>
    <!-- BUTTON that shows current colour -->
    <button class="swatch" style="background:{value}" on:click={openPicker}/>

    {#if isOpen}
        <div class="popup" bind:this={pickerRef}>
            <!-- iro.js mounts inside here -->
            <div class="iro-mount"></div>

            <!-- INPUT + toggle -->
            <div class="input-row">
                <input
                        type="text"
                        bind:value={inputValue}
                        on:input={onInputChange}
                        placeholder={isRgbInput ? 'r,g,b' : '#RRGGBB'}
                />

                <div class="toggle">
                    <label>
                        <input
                                type="checkbox"
                                bind:checked={isRgbInput}
                                on:change={()=>{
                                // convert displayed text when switching mode
                                if (isRgbInput) {
                                    const {r,g,b} = picker.color.rgb;
                                    inputValue = `${r},${g},${b}`;
                                } else {
                                    inputValue = picker.color.hexString;
                                }
                            }}
                        />
                        <span>{isRgbInput ? 'RGB' : 'HEX'}</span>
                    </label>
                </div>
            </div>
        </div>
    {/if}
</div>

<style>
    .color-picker { position:relative; display:inline-block; }

    .swatch {
        width:36px; height:36px; border-radius:6px;
        border:2px solid #ccc; cursor:pointer;
        box-shadow:0 0 4px rgba(0,0,0,0.2);
    }

    .popup {
        position:absolute; top:44px; left:0; z-index:999;
        background:#fff; padding:10px; border-radius:8px;
        box-shadow:0 4px 12px rgba(0,0,0,.3);
    }

    /* iro.js will fill .iro-mount automatically */
    .iro-mount { margin-bottom:8px; }

    .input-row { display:flex; gap:8px; align-items:center; }
    .input-row input {
        flex:1 1 auto; min-width:100px;
        padding:4px 6px; border:1px solid #ccc; border-radius:4px;
        font-family:monospace; font-size:0.9rem;
    }

    .toggle label {
        display:flex; align-items:center; gap:4px;
        font-size:0.75rem; user-select:none;
    }
</style>
