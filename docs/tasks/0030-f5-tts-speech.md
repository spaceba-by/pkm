# Task 0030: F5-TTS Speech Generation

**Status**: Planned

## Specifications

Add text-to-speech generation for daily summaries and weekly reports using F5-TTS, a high-quality neural text-to-speech model. The generated audio uses a custom voice clone from properly licensed or consented reference audio. Audio files are stored in S3 and delivered to the iOS app for playback alongside the text content.

### Architecture

- F5-TTS model hosted as a containerized service (ECS Fargate or SageMaker endpoint)
- Reference audio for voice cloning stored in S3
- Audio generation triggered after daily summary and weekly report creation
- Generated audio stored at `_agent/audio/summaries/{date}.mp3` and `_agent/audio/reports/{date}.mp3`
- iOS app adds audio playback controls to summary and report detail views

### Key Capabilities

- Voice cloning from licensed/consented reference audio samples
- Batch generation of audio for existing summaries and reports
- Streaming audio playback in iOS app
- Configurable: users can enable/disable audio generation in settings

## Relevant Files

### New Lambda/Container
- `lambda/functions/generate_audio/handler.clj` — Trigger audio generation
- `containers/f5-tts/` — F5-TTS container definition and model hosting

### Terraform
- `terraform/tts.tf` — ECS/SageMaker hosting, S3 paths, IAM, EventBridge triggers

### iOS
- `ios/PKMReader/Features/Insights/AudioPlayerView.swift` — Audio playback controls
- `ios/PKMReader/Core/Audio/AudioService.swift` — Audio streaming and caching

### Modified Files
- `lambda/functions/generate_daily_summary/handler.clj` — Trigger audio generation
- `lambda/functions/generate_weekly_report/handler.clj` — Trigger audio generation
- `ios/PKMReader/Features/Insights/SummaryDetailView.swift` — Add audio player
- `ios/PKMReader/Features/Insights/ReportDetailView.swift` — Add audio player

## Acceptance Criteria

- [ ] F5-TTS model hosted and accessible from Lambda
- [ ] Voice cloned from Amy Archer reference audio
- [ ] Audio generated for daily summaries and weekly reports
- [ ] Audio files stored in S3 and accessible via API
- [ ] iOS audio playback with play/pause, seek, and speed controls
- [ ] Audio generation can be enabled/disabled per user preference
- [ ] Batch generation tool for existing summaries and reports
- [ ] All existing tests continue to pass

## Implementation Steps

- [ ] Step 1: Set up F5-TTS container with voice cloning support
- [ ] Step 2: Prepare Amy Archer reference audio samples
- [ ] Step 3: Create audio generation Lambda
- [ ] Step 4: Add EventBridge trigger after summary/report generation
- [ ] Step 5: Add Terraform infrastructure for hosting
- [ ] Step 6: Create iOS AudioService for streaming playback
- [ ] Step 7: Add AudioPlayerView to summary and report detail views
- [ ] Step 8: Add user preference for audio generation
- [ ] Step 9: Create batch generation script for existing content
