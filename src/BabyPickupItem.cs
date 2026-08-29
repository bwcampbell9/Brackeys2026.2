using Godot;

public partial class BabyPickupItem : PickupItem, IBodyPushReceiver
{
    private static readonly StringName CrawlAnimation = "crawl";

    private AnimatedSprite2D _sprite = null!;
    private RandomNumberGenerator _random = null!;
    private Vector2 _targetPosition;
    private float _stateTime;
    private bool _isCrawling;
    private bool _isThrown;
    private float _pushSuppressionRemaining;

    [Export(PropertyHint.Range, "10,300,1,or_greater")]
    public float MinimumSpeed { get; set; } = 35.0f;

    [Export(PropertyHint.Range, "10,300,1,or_greater")]
    public float MaximumSpeed { get; set; } = 70.0f;

    [Export(PropertyHint.Range, "0.1,5,0.1,or_greater")]
    public float MinimumBurstDuration { get; set; } = 0.7f;

    [Export(PropertyHint.Range, "0.1,5,0.1,or_greater")]
    public float MaximumBurstDuration { get; set; } = 1.5f;

    [Export(PropertyHint.Range, "0.1,5,0.1,or_greater")]
    public float MinimumPauseDuration { get; set; } = 0.8f;

    [Export(PropertyHint.Range, "0.1,5,0.1,or_greater")]
    public float MaximumPauseDuration { get; set; } = 2.0f;

    [Export]
    public Rect2 CrawlBounds { get; set; } = new Rect2(96.0f, 96.0f, 768.0f, 320.0f);

    [Export(PropertyHint.Range, "0.05,1,0.05,or_greater")]
    public float PushSuppressionDuration { get; set; } = 0.2f;

    public override void _Ready()
    {
        base._Ready();
        _sprite = GetNode<AnimatedSprite2D>("AnimatedSprite2D");
        _random = new RandomNumberGenerator();
        _random.Randomize();
        StartPause();
    }

    public override void _PhysicsProcess(double delta)
    {
        if (!IsAvailable)
        {
            StopCrawling();
            return;
        }

        if (_pushSuppressionRemaining > 0.0f)
        {
            _pushSuppressionRemaining = Mathf.Max(
                0.0f,
                _pushSuppressionRemaining - (float)delta
            );
            return;
        }

        _stateTime -= (float)delta;
        if (_stateTime <= 0.0f)
        {
            if (_isCrawling)
            {
                StartPause();
            }
            else
            {
                StartBurst();
            }
        }

        if (!_isCrawling)
        {
            if (!_isThrown)
            {
                LinearVelocity = Vector2.Zero;
            }
            return;
        }

        Vector2 toTarget = _targetPosition - GlobalPosition;
        if (toTarget.LengthSquared() < 256.0f)
        {
            StartPause();
            LinearVelocity = Vector2.Zero;
            return;
        }

        LinearVelocity = toTarget.Normalized() * _random.RandfRange(
            MinimumSpeed,
            MaximumSpeed
        );
        SetCrawlFacing(LinearVelocity);
    }

    protected override void OnPickedUp()
    {
        _isThrown = false;
        StopCrawling();
    }

    protected override void OnThrown()
    {
        _isThrown = true;
        StartPause();
    }

    public void OnBodyPushed()
    {
        _pushSuppressionRemaining = PushSuppressionDuration;
        StopCrawling(false);
    }

    private void StartBurst()
    {
        _targetPosition = new Vector2(
            _random.RandfRange(CrawlBounds.Position.X, CrawlBounds.End.X),
            _random.RandfRange(CrawlBounds.Position.Y, CrawlBounds.End.Y)
        );
        _stateTime = _random.RandfRange(MinimumBurstDuration, MaximumBurstDuration);
        _isCrawling = true;
        _isThrown = false;
        _sprite.SpeedScale = _random.RandfRange(0.8f, 1.2f);
        _sprite.Play(CrawlAnimation);
    }

    private void StartPause()
    {
        _stateTime = _random.RandfRange(MinimumPauseDuration, MaximumPauseDuration);
        StopCrawling();
    }

    private void StopCrawling(bool stopMotion = true)
    {
        _isCrawling = false;
        if (stopMotion)
        {
            LinearVelocity = Vector2.Zero;
        }
        _sprite.Stop();
        _sprite.Frame = 0;
    }

    private void SetCrawlFacing(Vector2 velocity)
    {
        if (!Mathf.IsZeroApprox(velocity.X))
        {
            _sprite.FlipH = velocity.X < 0.0f;
        }

        float rotation = velocity.Angle();
        if (_sprite.FlipH)
        {
            rotation += Mathf.Pi;
        }

        Rotation = Mathf.Wrap(rotation, -Mathf.Pi, Mathf.Pi);
    }
}