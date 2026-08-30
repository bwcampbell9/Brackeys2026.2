using System;
using System.Collections.Generic;
using Godot;

public partial class GameScoreController : CanvasLayer
{
    private readonly List<WorkstationTaskPublisher> _publishers = new();
    private Label _scoreLabel = null!;
    private AudioStreamPlayer _scoreUpAudio = null!;
    private AudioStreamPlayer _scoreDownAudio = null!;
    private GameOverController _gameOverController = null!;
    private RandomNumberGenerator _random = null!;
    private Tween? _scoreTween;
    private float _displayedScore;
    private int _displayedScoreValue;
    private int _score;

    [Export]
    public NodePath ScoreLabelPath { get; set; } = new("Score");

    [Export]
    public NodePath ScoreUpAudioPath { get; set; } = new("ScoreUpAudio");

    [Export]
    public NodePath ScoreDownAudioPath { get; set; } = new("ScoreDownAudio");

    [Export]
    public int CorrectOrderPoints { get; set; } = 5;

    [Export]
    public int WrongOrderPenalty { get; set; } = 4;

    [Export]
    public int MissedOrderPenalty { get; set; } = 8;

    [Export(PropertyHint.Range, "1,10000,1,or_greater")]
    public int MaximumScore { get; set; } = 100;

    [Export(PropertyHint.Range, "1,10000,1,or_greater")]
    public int StartingScore { get; set; } = 50;

    [Export]
    public NodePath GameOverControllerPath { get; set; } =
        new("../GameOverController");

    [Export(PropertyHint.Range, "0.1,2,0.05,or_greater")]
    public float MaximumScoreTweenDuration { get; set; } = 0.65f;

    [Export(PropertyHint.Range, "0.05,1,0.05,or_greater")]
    public float ScoreTweenSecondsPerPoint { get; set; } = 0.06f;

    [Export(PropertyHint.Range, "0.05,1,0.05,or_greater")]
    public float ScorePopupIntroDuration { get; set; } = 0.18f;

    [Export(PropertyHint.Range, "0.1,2,0.05,or_greater")]
    public float ScorePopupRiseDuration { get; set; } = 0.65f;

    [Export(PropertyHint.Range, "0,90,1")]
    public float ScorePopupMaximumAngleDegrees { get; set; } = 12.0f;

    [Export(PropertyHint.Range, "1,200,1,or_greater")]
    public float ScorePopupVerticalOffset { get; set; } = 40.0f;

    [Export(PropertyHint.Range, "0.5,2,0.01")]
    public float ScoreTickMinimumPitchScale { get; set; } = 0.8f;

    [Export(PropertyHint.Range, "0.5,2,0.01")]
    public float ScoreTickMaximumPitchScale { get; set; } = 1.2f;

    public int Score => _score;

    public int GetScore()
    {
        return _score;
    }

    public override void _Ready()
    {
        _scoreLabel =
            GetNodeOrNull<Label>(ScoreLabelPath)
            ?? throw new InvalidOperationException(
                "GameScoreController requires a score label."
            );
        _scoreUpAudio =
            GetNodeOrNull<AudioStreamPlayer>(ScoreUpAudioPath)
            ?? throw new InvalidOperationException(
                "GameScoreController requires a score-up audio player."
            );
        _scoreDownAudio =
            GetNodeOrNull<AudioStreamPlayer>(ScoreDownAudioPath)
            ?? throw new InvalidOperationException(
                "GameScoreController requires a score-down audio player."
            );
        _gameOverController =
            GetNodeOrNull<GameOverController>(GameOverControllerPath)
            ?? throw new InvalidOperationException(
                "GameScoreController requires a game-over controller."
            );
        MaximumScore = Math.Max(1, MaximumScore);
        _score = Math.Clamp(StartingScore, 0, MaximumScore);
        _displayedScore = _score;
        _displayedScoreValue = _score;
        _random = new RandomNumberGenerator();
        _random.Randomize();
        UpdateScoreLabel(_score);
        Callable.From(ConnectPublishers).CallDeferred();
    }

    public override void _ExitTree()
    {
        foreach (WorkstationTaskPublisher publisher in _publishers)
        {
            if (GodotObject.IsInstanceValid(publisher))
            {
                publisher.CustomerOrderResolved -= ApplyCustomerOrderOutcome;
            }
        }
        _publishers.Clear();
    }

    private void ConnectPublishers()
    {
        foreach (
            Node node in GetTree().GetNodesInGroup(
                WorkstationTaskPublisher.PublisherGroup
            )
        )
        {
            if (
                node is not WorkstationTaskPublisher publisher
                || !publisher.ConsumeDeliveredItem
            )
            {
                continue;
            }

            publisher.CustomerOrderResolved += ApplyCustomerOrderOutcome;
            _publishers.Add(publisher);
        }
    }

    public void ApplyCustomerOrderOutcome(CustomerOrderOutcome outcome)
    {
        int scoreDelta = outcome switch
        {
            CustomerOrderOutcome.Correct => CorrectOrderPoints,
            CustomerOrderOutcome.Wrong => -WrongOrderPenalty,
            CustomerOrderOutcome.Missed => -MissedOrderPenalty,
            _ => throw new ArgumentOutOfRangeException(
                nameof(outcome),
                outcome,
                "Unknown customer order outcome."
            ),
        };
        int previousScore = _score;
        _score = Math.Clamp(previousScore + scoreDelta, 0, MaximumScore);
        int appliedDelta = _score - previousScore;
        if (appliedDelta != 0)
        {
            ShowScoreChange(appliedDelta);
            AnimateDisplayedScore();
        }
        if (_score == 0)
        {
            _gameOverController.TriggerGameOver();
        }
    }

    private void AnimateDisplayedScore()
    {
        _scoreTween?.Kill();
        float distance = Mathf.Abs(_score - _displayedScore);
        float duration = Mathf.Clamp(
            distance * Mathf.Max(0.01f, ScoreTweenSecondsPerPoint),
            0.1f,
            Mathf.Max(0.1f, MaximumScoreTweenDuration)
        );
        _scoreTween = CreateTween()
            .SetPauseMode(Tween.TweenPauseMode.Process)
            .SetIgnoreTimeScale();
        _scoreTween
            .TweenMethod(
                Callable.From<float>(SetDisplayedScore),
                _displayedScore,
                (float)_score,
                duration
            )
            .SetTrans(Tween.TransitionType.Linear);
        _scoreTween.Chain().TweenCallback(
            Callable.From(() => _scoreTween = null)
        );
    }

    private void SetDisplayedScore(float value)
    {
        _displayedScore = value;
        int displayedScore = Mathf.RoundToInt(value);
        if (displayedScore == _displayedScoreValue)
        {
            return;
        }

        bool increased = displayedScore > _displayedScoreValue;
        _displayedScoreValue = displayedScore;
        UpdateScoreLabel(displayedScore);
        PlayScoreTick(increased ? _scoreUpAudio : _scoreDownAudio);
    }

    private void PlayScoreTick(AudioStreamPlayer audioPlayer)
    {
        float minimumPitch = Mathf.Max(0.01f, ScoreTickMinimumPitchScale);
        float maximumPitch = Mathf.Max(minimumPitch, ScoreTickMaximumPitchScale);
        audioPlayer.PitchScale = _random.RandfRange(
            minimumPitch,
            maximumPitch
        );
        audioPlayer.Play();
    }

    private void ShowScoreChange(int scoreDelta)
    {
        Label popup = new()
        {
            Name = "ScoreChange",
            Text = scoreDelta > 0 ? $"+{scoreDelta}" : scoreDelta.ToString(),
            Position =
                _scoreLabel.Position
                + new Vector2(0.0f, Mathf.Max(1.0f, ScorePopupVerticalOffset)),
            Size = _scoreLabel.Size,
            HorizontalAlignment = _scoreLabel.HorizontalAlignment,
            VerticalAlignment = VerticalAlignment.Center,
            MouseFilter = Control.MouseFilterEnum.Ignore,
            SelfModulate = scoreDelta > 0 ? Colors.LimeGreen : Colors.Red,
            Rotation = Mathf.DegToRad(
                _random.RandfRange(
                    -Mathf.Max(0.0f, ScorePopupMaximumAngleDegrees),
                    Mathf.Max(0.0f, ScorePopupMaximumAngleDegrees)
                )
            ),
            Scale = Vector2.One * 0.65f,
            Modulate = new Color(1.0f, 1.0f, 1.0f, 0.0f),
        };
        popup.PivotOffset = popup.Size * 0.5f;
        popup.AddThemeFontOverride("font", _scoreLabel.GetThemeFont("font"));
        popup.AddThemeFontSizeOverride(
            "font_size",
            _scoreLabel.GetThemeFontSize("font_size") * 2
        );
        popup.AddThemeColorOverride(
            "font_color",
            _scoreLabel.GetThemeColor("font_color")
        );
        popup.AddThemeColorOverride(
            "font_outline_color",
            _scoreLabel.GetThemeColor("font_outline_color")
        );
        popup.AddThemeConstantOverride(
            "outline_size",
            _scoreLabel.GetThemeConstant("outline_size")
        );
        AddChild(popup);

        float introDuration = Mathf.Max(0.05f, ScorePopupIntroDuration);
        float riseDuration = Mathf.Max(0.1f, ScorePopupRiseDuration);
        Tween popupTween = CreateTween()
            .SetPauseMode(Tween.TweenPauseMode.Process)
            .SetIgnoreTimeScale();
        popupTween
            .TweenProperty(popup, "scale", Vector2.One, introDuration)
            .SetTrans(Tween.TransitionType.Back)
            .SetEase(Tween.EaseType.Out);
        popupTween
            .Parallel()
            .TweenProperty(popup, "modulate:a", 1.0f, introDuration);
        popupTween
            .TweenProperty(
                popup,
                "position",
                _scoreLabel.Position,
                riseDuration
            )
            .SetTrans(Tween.TransitionType.Quad)
            .SetEase(Tween.EaseType.In);
        popupTween
            .Parallel()
            .TweenProperty(popup, "rotation", 0.0f, riseDuration);
        popupTween
            .Parallel()
            .TweenProperty(popup, "scale", Vector2.One * 0.8f, riseDuration);
        popupTween
            .Parallel()
            .TweenProperty(popup, "modulate:a", 0.0f, riseDuration);
        popupTween.TweenCallback(Callable.From(popup.QueueFree));
    }

    private void UpdateScoreLabel(int displayedScore)
    {
        _scoreLabel.Text = $"Score: {displayedScore} / {MaximumScore}";
    }
}
