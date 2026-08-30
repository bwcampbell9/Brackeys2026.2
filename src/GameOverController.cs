using Godot;
using System;

public partial class GameOverController : CanvasLayer
{
	private enum GameOverPhase
	{
		Playing,
		BabyCinematic,
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
	private static readonly NodePath CameraZoomProperty = "zoom";
	private static readonly NodePath GlobalPositionProperty = "global_position";
	private const string ExecutionerScenePath = "res://scenes/executioner.tscn";
	private const string TitleScenePath = "res://scenes/title_screen.tscn";

	private Node2D _player = null!;
	private BabyPickupItem _baby = null!;
	private PauseMenu _pauseMenu = null!;
	private ColorRect _overlay = null!;
	private ShaderMaterial _overlayMaterial = null!;
	private Executioner? _executioner;
	private Camera2D? _babyDeathCamera;
	private Tween? _babyCinematicTween;
	private GameOverPhase _phase;
	private double _elapsed;
	private double _previousTimeScale = 1.0;
	private bool _usingBabySlowMotion;

	[Export]
	public NodePath PlayerPath { get; set; } = "../Player";

	[Export]
	public NodePath BabyPath { get; set; } = "../BabyPickupItem";

	[Export]
	public NodePath PauseMenuPath { get; set; } = "../PauseMenu";

	[Export(PropertyHint.Range, "0.1,5,0.1,or_greater")]
	public float BabyCinematicDuration { get; set; } = 1.25f;

	[Export(PropertyHint.Range, "0.01,1,0.01")]
	public float BabySlowMotionScale { get; set; } = 0.2f;

	[Export(PropertyHint.Range, "1,8,0.1,or_greater")]
	public float BabyFocusZoom { get; set; } = 3.0f;

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
		_baby =
			GetNodeOrNull<BabyPickupItem>(BabyPath)
			?? throw new InvalidOperationException(
				"GameOverController requires a baby pickup item."
			);
		_baby.Died += OnBabyDied;
		_pauseMenu =
			GetNodeOrNull<PauseMenu>(PauseMenuPath)
			?? throw new InvalidOperationException(
				"GameOverController requires a pause menu."
			);

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

	public override void _ExitTree()
	{
		if (GodotObject.IsInstanceValid(_baby))
		{
			_baby.Died -= OnBabyDied;
		}
		CleanupBabyCinematic();
	}

	public override void _Process(double delta)
	{
		if (!GetTree().Paused && Input.IsActionJustPressed(GameOverAction))
		{
			TriggerGameOver();
		}

		if (
			_phase == GameOverPhase.Playing
			|| _phase == GameOverPhase.BabyCinematic
			|| _phase == GameOverPhase.Complete
		)
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

		_pauseMenu.LockForGameOver();
		BeginGameOver();
	}

	private void OnBabyDied(BabyDeathCause _)
	{
		if (_phase != GameOverPhase.Playing)
		{
			return;
		}

		_pauseMenu.LockForGameOver();
		_phase = GameOverPhase.BabyCinematic;
		_previousTimeScale = Engine.TimeScale;
		_usingBabySlowMotion = true;
		Engine.TimeScale = Mathf.Clamp(BabySlowMotionScale, 0.01f, 1.0f);

		Node2D sceneRoot =
			GetTree().CurrentScene as Node2D
			?? throw new InvalidOperationException(
				"Baby game over requires a Node2D current scene."
			);
		Camera2D? currentCamera = GetViewport().GetCamera2D();
		Vector2 initialPosition =
			currentCamera?.GetScreenCenterPosition()
			?? GetViewport().GetVisibleRect().Size * 0.5f;
		Vector2 initialZoom = currentCamera?.Zoom ?? Vector2.One;
		Vector2 babyPosition = _baby.GlobalPosition;

		_babyDeathCamera = new Camera2D
		{
			Name = "BabyDeathCamera",
			ProcessMode = ProcessModeEnum.Always,
			Zoom = initialZoom,
		};
		sceneRoot.AddChild(_babyDeathCamera);
		_babyDeathCamera.GlobalPosition = initialPosition;
		_babyDeathCamera.MakeCurrent();

		_babyCinematicTween = CreateTween()
			.SetParallel()
			.SetPauseMode(Tween.TweenPauseMode.Process)
			.SetIgnoreTimeScale();
		_babyCinematicTween
			.TweenProperty(
				_babyDeathCamera,
				GlobalPositionProperty,
				babyPosition,
				Mathf.Max(0.1f, BabyCinematicDuration)
			)
			.SetTrans(Tween.TransitionType.Quad)
			.SetEase(Tween.EaseType.Out);
		_babyCinematicTween
			.TweenProperty(
				_babyDeathCamera,
				CameraZoomProperty,
				Vector2.One * Mathf.Max(1.0f, BabyFocusZoom),
				Mathf.Max(0.1f, BabyCinematicDuration)
			)
			.SetTrans(Tween.TransitionType.Quad)
			.SetEase(Tween.EaseType.Out);
		_babyCinematicTween.Chain().TweenCallback(
			Callable.From(FinishBabyCinematic)
		);
	}

	private void FinishBabyCinematic()
	{
		_babyCinematicTween = null;
		RestoreTimeScale();
		if (
			_babyDeathCamera is not null
			&& GodotObject.IsInstanceValid(_babyDeathCamera)
		)
		{
			_babyDeathCamera.QueueFree();
		}
		_babyDeathCamera = null;
		BeginGameOver();
	}

	private void CleanupBabyCinematic()
	{
		_babyCinematicTween?.Kill();
		_babyCinematicTween = null;
		if (
			_babyDeathCamera is not null
			&& GodotObject.IsInstanceValid(_babyDeathCamera)
		)
		{
			_babyDeathCamera.QueueFree();
		}
		_babyDeathCamera = null;
		RestoreTimeScale();
	}

	private void RestoreTimeScale()
	{
		if (!_usingBabySlowMotion)
		{
			return;
		}

		Engine.TimeScale = _previousTimeScale;
		_usingBabySlowMotion = false;
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
