document.addEventListener('DOMContentLoaded', () => {
  const form = document.querySelector('.url-form');
  const result = document.querySelector('.result-section .container');

  // ✅ Safety check (VERY IMPORTANT)
  if (!form) {
    console.error("Form not found — JS not attached");
    return;
  }

  form.addEventListener('submit', async (event) => {
    event.preventDefault();

    const input = document.querySelector('.url-input');

    if (!input || !input.value.trim()) {
      alert("Please enter a valid URL");
      return;
    }

    try {
      const response = await fetch('/shorten', {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          destination: input.value.trim(),
        }),
      });

      if (!response.ok) {
        throw new Error("Request failed");
      }

      const data = await response.json();

      // ✅ Correct short URL
      const url = location.origin + '/' + data.shortID;

      // Clear input AFTER success
      input.value = '';

      result.insertAdjacentHTML(
        'afterbegin',
        `
        <div class="card mb-5">
          <div class="card-content">
            <div class="content is-flex is-justify-content-space-between">
              <div>
                <h3 class="title has-text-link">
                  <a class="has-text-black" target="_blank" rel="noopener" href="${url}">
                    ${url}
                  </a>
                </h3>
                <p class="subtitle is-6 has-text-primary-dark">
                  ${data.destination}
                </p>
              </div>
              <div class="field is-grouped">
                <p class="control">
                  <a
                    href="${url}"
                    target="_blank"
                    rel="noopener"
                    class="button has-text-link"
                  >
                    <span class="icon is-small">
                      <i class="fa-solid fa-arrow-up-right-from-square"></i>
                    </span>
                    <span>Visit</span>
                  </a>
                </p>
                <p class="control has-text-primary">
                  <button data-url="${url}" class="button copy-link js-copy-link">
                    <span class="icon is-small">
                      <i class="fa-solid fa-copy"></i>
                    </span>
                    <span class="copy-text">Copy</span>
                  </button>
                </p>
              </div>
            </div>
          </div>
        </div>
        `
      );

    } catch (err) {
      console.error("Error:", err);
      alert("Something went wrong");
    }
  });

  // ✅ Copy button logic (safe version)
  document.addEventListener('click', (e) => {
    const button = e.target.closest('.js-copy-link');
    if (!button) return;

    const copyText = button.querySelector('.copy-text');
    const url = button.dataset.url;

    navigator.clipboard.writeText(url);

    if (copyText) {
      copyText.textContent = 'Copied!';
      setTimeout(() => {
        copyText.textContent = 'Copy';
      }, 2000);
    }
  });
});
