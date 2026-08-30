using Godot;
using System;

public partial class GameOverController : CanvasLayer
{
	private enum GameOverPhase
	{
		Playing,
		Fading,
		ExecutionerIdle,
		ExecutionerWalking,
		Takeout,
		Chop,
		Complete,
	}

	private static readonly StringName GameOverAction = "game_over";
	private static readonly StringName FocusUvParameter = "focus_uv";
	private static readonly StringName ProgressParameter = "progress";
	private const string ExecutionerScenePath = "res://scenes/executioner.tscn";
	private const string TitleScenePath = "res://scenes/title_screen.tscn";

	private Node2D _player = null!;
	private ColorRect _overlay = null!;
	private ShaderMaterial _overlayMaterial = null!;
	private Executioner? _executioner;
	private GameOverPhase _phase;
	private double _elapsed;

	[Export]
	public NodePath PlayerPath { get; set; } = "../Player";

	[Export(PropertyHint.Range, "0.1,5,0.1,or_greater")]
	public float RevealDuration { get; set; } = 0.75f;

	[Export(PropertyHint.Range, "0.1,5,0.1,or_greater")]
	public float ExecutionerIdleDuration { get; set; } = 1.0f;

	[Export(PropertyHint.Range, "10,1000,1,or_greater")]
	public float ExecutionerWalkSpeed { get; set; } = 220.0f;

	public override void _Ready()
	{
		ProcessMode = ProcessModeEnum.Always;
		RevealDuration = Mathf.Max(RevealDuration, 0.1f);
		ExecutionerIdleDuration = Mathf.Max(ExecutionerIdleDuration, 0.1f);
		ExecutionerWalkSpeed = Mathf.Max(ExecutionerWalkSpeed, 10.0f);
		_player = GetNode<Node2D>(PlayerPath);

		_overlayMaterial = new ShaderMaterial
		{
			Shader = GD.Load<Shader>("res://assets/shaders/game_over.gdshader"),
		};
		_overlay = new ColorRect
		{
			Material = _overlayMaterial,
			MouseFilter = Control.MouseFilterEnum.Ignore,
			Visible = false,
		};
		_overlay.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
		AddChild(_overlay);
	}

	public override void _Process(double delta)
	{
		if (!GetTree().Paused && Input.IsActionJustPressed(GameOverAction))
		{
			TriggerGameOver();
		}

		if (_phase == GameOverPhase.Playing || _phase == GameOverPhase.Complete)
		{
			return;
		}

		_elapsed += delta;
		Vector2 viewportSize = GetViewport().GetVisibleRect().Size;
		Vector2 focusUv = _player.GlobalPosition / viewportSize;
		_overlayMaterial.SetShaderParameter(FocusUvParameter, focusUv);

		if (_phase == GameOverPhase.Fading)
		{
			float progress = Mathf.Clamp(
				(float)(_elapsed / RevealDuration),
				0.0f,
				1.0f
			);
			_overlayMaterial.SetShaderParameter(ProgressParameter, progress);
			if (progress >= 1.0f)
			{
				SpawnExecutioner();
			}
			return;
		}

		if (_phase == GameOverPhase.ExecutionerIdle)
		{
			if (_elapsed >= ExecutionerIdleDuration)
			{
				_phase = GameOverPhase.ExecutionerWalking;
				_executioner!.PlayWalk();
			}
			return;
		}

		if (_phase == GameOverPhase.ExecutionerWalking)
		{
			UpdateExecutionerWalk((float)delta);
		}
	}

	public void TriggerGameOver()
	{
		if (_phase != GameOverPhase.Playing)
		{
			return;
		}

		BeginGameOver();
	}

	private void BeginGameOver()
	{
		_phase = GameOverPhase.Fading;
		_elapsed = 0.0;
		_overlay.Visible = true;
		GetTree().Paused = true;
	}

	private void SpawnExecutioner()
	{
		PackedScene executionerScene = GD.Load<PackedScene>(ExecutionerScenePath)
			?? throw new InvalidOperationException(
				$"Could not load executioner scene at '{ExecutionerScenePath}'."
			);
		_executioner = executionerScene.Instantiate<Executioner>();
		_executioner.ProcessMode = ProcessModeEnum.Always;
		_executioner.GlobalPosition = new Vector2(_player.GlobalPosition.X, -64.0f);
		_executioner.AnimationFinished += OnExecutionerAnimationFinished;
		GetTree().CurrentScene.AddChild(_executioner);
		_executioner.PlayIdle();
		_phase = GameOverPhase.ExecutionerIdle;
		_elapsed = 0.0;
	}

	private void UpdateExecutionerWalk(float delta)
	{
		Vector2 targetPosition = _player.GlobalPosition + new Vector2(0.0f, -110.0f);
		_executioner!.GlobalPosition = _executioner.GlobalPosition.MoveToward(
			targetPosition,
			ExecutionerWalkSpeed * delta
		);
		if (_executioner.GlobalPosition.IsEqualApprox(targetPosition))
		{
			_phase = GameOverPhase.Takeout;
			_executioner.PlayTakeout();
		}
	}

	private void OnExecutionerAnimationFinished()
	{
		if (_phase == GameOverPhase.Takeout)
		{
			_phase = GameOverPhase.Chop;
			_executioner!.PlayChop();
		}
		else if (_phase == GameOverPhase.Chop)
		{
			ShowCompletionMenu();
		}
	}

	private void ShowCompletionMenu()
	{
		_phase = GameOverPhase.Complete;
		_overlay.Material = null;
		_overlay.Color = Colors.Black;

		VBoxContainer menu = new()
		{
			AnchorLeft = 0.5f,
			AnchorTop = 0.5f,
			AnchorRight = 0.5f,
			AnchorBottom = 0.5f,
			OffsetLeft = -96.0f,
			OffsetTop = -48.0f,
			OffsetRight = 96.0f,
			OffsetBottom = 48.0f,
			MouseFilter = Control.MouseFilterEnum.Stop,
		};
		Button retryButton = new()
		{
			Name = "RetryButton",
			Text = "Retry",
			CustomMinimumSize = new Vector2(192.0f, 40.0f),
			FocusNeighborTop = "../ExitButton",
			FocusNeighborBottom = "../ExitButton",
		};
		Button exitButton = new()
		{
			Name = "ExitButton",
			Text = "Exit",
			CustomMinimumSize = new Vector2(192.0f, 40.0f),
			FocusNeighborTop = "../RetryButton",
			FocusNeighborBottom = "../RetryButton",
		};
		retryButton.Pressed += RestartScene;
		exitButton.Pressed += ReturnToTitle;
		menu.AddChild(retryButton);
		menu.AddChild(exitButton);
		AddChild(menu);
		retryButton.GrabFocus();
	}

	private void RestartScene()
	{
		GetTree().Paused = false;
		GetTree().ReloadCurrentScene();
	}

	private void ReturnToTitle()
	{
		GetTree().Paused = false;
		GetTree().ChangeSceneToFile(TitleScenePath);
	}
}
