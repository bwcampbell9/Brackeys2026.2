using Godot;

public partial class BobbingMenuArt : TextureRect
{
    [Export(PropertyHint.Range, "0,20,0.5,or_greater")]
    public float Amplitude { get; set; } = 4.0f;

    [Export(PropertyHint.Range, "0.5,10,0.1,or_greater")]
    public float Period { get; set; } = 4.0f;

    [Export(PropertyHint.Range, "0,6.283,0.01")]
    public float Phase { get; set; }

    private Vector2 _restPosition;
    private double _elapsed;

    public override void _Ready()
    {
        _restPosition = Position;
        Period = Mathf.Max(Period, 0.5f);
    }

    public override void _Process(double delta)
    {
        _elapsed += delta;
        float offset = Mathf.Sin((float)(_elapsed * Mathf.Tau / Period) + Phase) * Amplitude;
        Position = _restPosition + Vector2.Up * offset;
    }
}
