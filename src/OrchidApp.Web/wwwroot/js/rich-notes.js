/* OrchidApp shared Razor Pages integration; Quill is bundled locally. */
(() => {
    "use strict";
    document.querySelectorAll("textarea[data-rich-notes]").forEach(field => {
        if (typeof Quill === "undefined") return; // Keep the normal textarea usable.
        const wrapper = document.createElement("div");
        wrapper.className = "orchid-rich-editor";
        const host = document.createElement("div");
        const status = document.createElement("div");
        status.className = "small text-muted mt-1";
        status.setAttribute("aria-live", "polite");
        field.after(wrapper);
        wrapper.append(host, status);
        const editor = new Quill(host, {
            theme: "snow",
            formats: ["bold", "italic", "underline", "list"],
            modules: { toolbar: [["bold", "italic", "underline"], [{ list: "bullet" }, { list: "ordered" }], ["clean"]] }
        });
        const marker = "<!--orchid-rich-notes:v1-->";
        if (field.value.startsWith(marker)) {
            editor.setContents(editor.clipboard.convert({ html: field.dataset.editorHtml }));
        } else {
            editor.setText(field.value);
        }
        editor.root.setAttribute("role", "textbox");
        editor.root.setAttribute("aria-multiline", "true");
        editor.root.setAttribute("aria-label", field.dataset.label || "Notes");
        if (field.getAttribute("aria-describedby")) editor.root.setAttribute("aria-describedby", field.getAttribute("aria-describedby"));
        const labels = { bold: "Bold", italic: "Italic", underline: "Underline", clean: "Clear formatting" };
        wrapper.querySelectorAll(".ql-toolbar button").forEach(button => {
            const type = [...button.classList].find(c => c.startsWith("ql-")).slice(3);
            const label = type === "list" ? (button.value === "bullet" ? "Bulleted list" : "Numbered list") : labels[type];
            button.setAttribute("aria-label", label);
            button.title = label;
            button.type = "button";
        });
        field.hidden = true;
        const sync = () => {
            field.value = marker + editor.getSemanticHTML();
            const length = editor.getLength() - 1;
            status.textContent = `${length.toLocaleString()} / 10,000 characters`;
            return length <= 10000;
        };
        editor.on("text-change", sync);
        sync();
        field.form.addEventListener("submit", event => {
            if (!sync()) {
                event.preventDefault();
                status.textContent = "Notes must contain no more than 10,000 characters. Please shorten the note.";
                editor.focus();
            }
        });
        // Existing labels should focus the enhanced editor too.
        document.querySelector(`label[for="${field.id}"]`)?.addEventListener("click", event => {
            event.preventDefault();
            editor.focus();
        });
    });
})();
