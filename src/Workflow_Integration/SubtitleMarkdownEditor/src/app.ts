declare const __BUILD_HASH__: string;

document.addEventListener('DOMContentLoaded', () => {
    const btnLoad = document.getElementById('btn-load') as HTMLButtonElement | null;
    const btnApply = document.getElementById('btn-apply') as HTMLButtonElement | null;
    const editor = document.getElementById('editor') as HTMLTextAreaElement | null;
    const status = document.getElementById('status') as HTMLDivElement | null;
    const buildHashEl = document.getElementById('build-hash') as HTMLDivElement | null;

    if (!btnLoad || !btnApply || !editor || !status) return;

    if (buildHashEl) {
        buildHashEl.innerText = __BUILD_HASH__;
    }

    let fps = 24;

    function formatTimecode(frames: number, frameRate: number) {
        const timeSeconds = frames / frameRate;
        const h = Math.floor(timeSeconds / 3600);
        const m = Math.floor((timeSeconds % 3600) / 60);
        const s = Math.floor(timeSeconds % 60);
        const ms = Math.floor((timeSeconds - Math.floor(timeSeconds)) * 1000);

        const pad = (num: number, size: number) => num.toString().padStart(size, '0');
        return `${pad(h, 2)}:${pad(m, 2)}:${pad(s, 2)},${pad(ms, 3)}`;
    }

    btnLoad.addEventListener('click', async () => {
        status.innerText = "Loading subtitles...";
        try {
            const data = await (window as any).resolveAPI.getSubtitles();
            if (data.error) {
                status.innerText = "Error: " + data.error;
                return;
            }

            if (!data.subtitles || data.subtitles.length === 0) {
                status.innerText = "No subtitles found on track 1.";
                return;
            }

            // Parse FPS and Timeline Start
            const frameRateStr = String(data.frameRate || "24");
            fps = parseFloat(frameRateStr.replace(" DF", "").replace(" NDF", ""));
            if (isNaN(fps)) fps = 24;
            const timelineStartFrame = data.timelineStartFrame || 0;

            let markdown = "";
            data.subtitles.forEach((sub: any, index: number) => {
                // Subtract the timeline start frame to make it 0-based for SRT
                const startTc = formatTimecode(sub.start - timelineStartFrame, fps);
                const endTc = formatTimecode(sub.end - timelineStartFrame, fps);
                markdown += `[${startTc} --> ${endTc}]\n${sub.name}\n\n`;
            });

            editor.value = markdown;
            status.innerText = `Loaded ${data.subtitles.length} subtitles seamlessly.`;
        } catch (err: any) {
            status.innerText = "Error: " + err.message;
        }
    });

    btnApply.addEventListener('click', async () => {
        status.innerText = "Applying changes...";
        try {
            const text = editor.value.trim();
            if (!text) {
                status.innerText = "Editor is empty.";
                return;
            }

            // Simplest SRT conversion
            const blocks = text.split(/\n\n+/);
            let srtContent = "";
            let counter = 1;

            for (const block of blocks) {
                const lines = block.trim().split('\n');
                if (lines.length < 2) continue;

                const timeMatch = lines[0].match(/\[(.*?) --> (.*?)\]/);
                if (timeMatch) {
                    const startTc = timeMatch[1].trim().replace('.', ',');
                    const endTc = timeMatch[2].trim().replace('.', ',');
                    const content = lines.slice(1).join('\n');

                    srtContent += `${counter}\r\n${startTc} --> ${endTc}\r\n${content}\r\n\r\n`;
                    counter++;
                }
            }

            console.log("SRT Length:", srtContent.length);

            const res = await (window as any).resolveAPI.applySubtitles(srtContent);
            if (res.error) {
                status.innerText = "Error applying: " + res.error;
            } else {
                status.innerText = "Successfully appended modified subtitle track to timeline.";
            }

        } catch (err: any) {
            status.innerText = "Error: " + err.message;
        }
    });
});
