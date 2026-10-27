# OpenSubtitles lookup review

Reviewed 27 October 2026 for Film knowledge task [031](../../specs/031_researched_analysis_generation.md).

The owner identified the [subtitle-search endpoint](https://opensubtitles.stoplight.io/docs/opensubtitles-api/a172317bd5ccc-search-for-subtitles). Its client-rendered documentation was not readable through the web fetch, so the review used the provider's [API reference](https://ai.opensubtitles.com/api-docs) and [official implementation guide](https://blog.opensubtitles.com/opensubtitles/how-to-build-a-movie-subtitle-finder-cli-with-python-and-the-opensubtitles-api).

The API supports `tmdb_id` on `GET /api/v1/subtitles`. For Alien the discovery request is:

```text
GET https://api.opensubtitles.com/api/v1/subtitles?languages=en&tmdb_id=348&type=movie
Api-Key: <application key from environment>
User-Agent: <registered application name/version>
```

This is a documentation example; no live subtitle request was executed. Search returns candidates, not subtitle text. The next operation is `POST /download` with the candidate's `files[].file_id`, followed by retrieval from its temporary download URL. Requesting a download consumes an allowance. Authentication and quota handling must follow the actual account/API response; the API reference and recent official guide differ about when a user token is required. No quota, key validity or anonymous download access has been verified here.

TMDB lookup is preferable to a title-only search for identifying the film. It does not identify the exact release/cut, nor confirm that a caption supports a factual claim. A direct integration should retain the subtitle/file IDs, language, release name, film metadata, SDH flag and translation flags; prefer original-language, non-machine/non-AI-translated candidates and inspect available version information before counting cues as evidence. Download count or trusted-uploader flags alone do not establish a correct match. A subtitle mirror and its underlying original are one source origin.

The current task names OpenSubtitles in the managed research prompt and accepts suitably evidenced, web-inspected caption sources. It does not yet implement authenticated API search/download: hosted web search cannot attach the application's API key or obtain quota-bearing downloads on its behalf. A direct adapter is a concrete optional follow-up, with fake response/download tests, an explicit download cap and credentials supplied through the environment. It would supply caption content inside the same developer-facing research/analysis operation, without a human preparation stage. It must not put API credentials or temporary authorized download URLs into prompts, traces or committed evidence.

No API account, paid plan, subtitle download, translation or transcription was created or invoked during this review.


## Owner decision — task 031a

The owner chose to try research without OpenSubtitles for now, noting expected subscription costs at catalogue volume. No pricing conclusion was independently verified by this task. Current development prompt v5 excludes OpenSubtitles; generated source admission also rejects opensubtitles.com/.org and their subdomains. The API findings above remain historical integration research, not an active retrieval plan. Accessible independent articles, plot accounts, reviews and production sources remain available to the model; no replacement subtitle service or subscription was selected.
