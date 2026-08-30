using Godot;

public partial class Executioner : Node2D
{
    private static readonly StringName IdleAnimation = "idle";
    private static readonly StringName WalkAnimation = "walk";
    private static readonly StringName TakeoutAnimation = "takeout";
    private static readonly StringName ChopAnimation = "chop";

    private AnimatedSprite2D _sprite = null!;
    private AudioStreamPlayer _walkAudio = null!;
    private AudioStreamPlayer _chopAudio = null!;
    private bool _isWalking;

    public event System.Action? AnimationFinished;

    public override void _Ready()
    {
        _sprite = GetNode<AnimatedSprite2D>("AnimatedSprite2D");
        _walkAudio = GetNode<AudioStreamPlayer>("WalkAudio");
        _chopAudio = GetNode<AudioStreamPlayer>("ChopAudio");
        _sprite.AnimationFinished += OnAnimationFinished;
        _walkAudio.Finished += OnWalkAudioFinished;
        PlayIdle();
    }

    public void PlayIdle()
    {
        _isWalking = false;
        _walkAudio.Stop();
        _sprite.Play(IdleAnimation);
    }

    public void PlayWalk()
    {
        _isWalking = true;
        _sprite.Play(WalkAnimation);
        _walkAudio.Play();
    }

    public void PlayTakeout()
    {
        _isWalking = false;
        _walkAudio.Stop();
        _sprite.Play(TakeoutAnimation);
    }

    public void PlayChop()
    {
        _isWalking = false;
        _walkAudio.Stop();
        _sprite.Play(ChopAnimation);
        _chopAudio.Play();
    }

    private void OnAnimationFinished()
    {
        AnimationFinished?.Invoke();
    }

    private void OnWalkAudioFinished()
    {
        if (_isWalking)
        {
            _walkAudio.Play();
        }
    }
}