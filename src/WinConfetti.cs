using System.Collections.Generic;
using Godot;

public partial class WinConfetti : CanvasLayer
{
    private sealed class Piece
    {
        public required ColorRect Visual { get; init; }
        public Vector2 Velocity { get; set; }
        public float AngularVelocity { get; init; }
        public float FlutterSpeed { get; init; }
        public float FlutterPhase { get; init; }
    }

    private const int PieceCount = 72;
    private const float Lifetime = 2.25f;
    private const float FadeDuration = 0.4f;
    private const float Gravity = 700.0f;
    private static readonly Color[] Palette =
    [
        new("ff4d6d"),
        new("ffca3a"),
        new("8ac926"),
        new("00bbf9"),
        new("9b5de5"),
        new("ff70a6"),
    ];

    private readonly List<Piece> _pieces = new(PieceCount);
    private float _elapsed;

    public override void _Ready()
    {
        Layer = 90;
        ProcessMode = ProcessModeEnum.Always;
    }

    public void Burst(Vector2 origin)
    {
        RandomNumberGenerator random = new();
        random.Randomize();

        for (int index = 0; index < PieceCount; index++)
        {
            Vector2 size = new(
                random.RandfRange(6.0f, 12.0f),
                random.RandfRange(10.0f, 20.0f)
            );
            ColorRect visual = new()
            {
                Color = Palette[index % Palette.Length],
                MouseFilter = Control.MouseFilterEnum.Ignore,
                Position = origin - (size * 0.5f),
                PivotOffset = size * 0.5f,
                Rotation = random.RandfRange(-Mathf.Pi, Mathf.Pi),
                Size = size,
            };
            AddChild(visual);

            float angle = Mathf.DegToRad(random.RandfRange(-165.0f, -15.0f));
            float speed = random.RandfRange(280.0f, 560.0f);
            _pieces.Add(
                new Piece
                {
                    Visual = visual,
                    Velocity = Vector2.FromAngle(angle) * speed,
                    AngularVelocity = random.RandfRange(-9.0f, 9.0f),
                    FlutterSpeed = random.RandfRange(8.0f, 16.0f),
                    FlutterPhase = random.RandfRange(0.0f, Mathf.Tau),
                }
            );
        }
    }

    public override void _Process(double delta)
    {
        float frameSeconds = (float)delta;
        _elapsed += frameSeconds;
        float alpha = Mathf.Clamp(
            (Lifetime - _elapsed) / FadeDuration,
            0.0f,
            1.0f
        );

        foreach (Piece piece in _pieces)
        {
            piece.Velocity += Vector2.Down * Gravity * frameSeconds;
            piece.Visual.Position += piece.Velocity * frameSeconds;
            piece.Visual.Rotation += piece.AngularVelocity * frameSeconds;
            piece.Visual.Scale = new Vector2(
                Mathf.Max(
                    0.15f,
                    Mathf.Abs(
                        Mathf.Sin(
                            (_elapsed * piece.FlutterSpeed) + piece.FlutterPhase
                        )
                    )
                ),
                1.0f
            );
            piece.Visual.Modulate = new Color(1.0f, 1.0f, 1.0f, alpha);
        }

        if (_elapsed >= Lifetime)
        {
            SetProcess(false);
            QueueFree();
        }
    }
}
