using System.Collections.Generic;
using Godot;
using Godot.Collections;

public partial class PlayerInputManager : Node
{
    private sealed class InputState
    {
        public float HeldTime;
        public bool HoldActivated;
        public bool HoldThresholdReached;
    }

    private static readonly StringName DefaultInputAction = "interact";

    private readonly System.Collections.Generic.Dictionary<
        StringName,
        InputState
    > _inputStates = new();
    private Node2D _actor = null!;
    private PlayerInteractor _interactor = null!;
    private PickupCarrier _carrier = null!;

    [Export(PropertyHint.Range, "0.05,2,0.01,or_greater")]
    public float HoldThreshold { get; set; } = 0.35f;

    [Export]
    public Array<InteractionInputBinding> InteractionInputs { get; set; } =
        CreateDefaultBindings();

    public override void _Ready()
    {
        _actor = GetParent<Node2D>();
        _interactor = _actor.GetNode<PlayerInteractor>("Interactor");
        _carrier = _actor.GetNode<PickupCarrier>("PickupCarrier");

        EnsureDefaultBindings();
        foreach (InteractionInputBinding binding in InteractionInputs)
        {
            if (
                !binding.InputAction.IsEmpty
                && !_inputStates.ContainsKey(binding.InputAction)
            )
            {
                _inputStates.Add(binding.InputAction, new InputState());
            }
        }
    }

    public override void _PhysicsProcess(double delta)
    {
        foreach (
            KeyValuePair<StringName, InputState> entry in _inputStates
        )
        {
            StringName inputAction = entry.Key;
            InputState state = entry.Value;
            bool justPressed = Input.IsActionJustPressed(inputAction);
            bool justReleased = Input.IsActionJustReleased(inputAction);
            bool wasHoldActivated = state.HoldActivated;
            bool wasHoldThresholdReached = state.HoldThresholdReached;

            if (justPressed)
            {
                if (wasHoldActivated)
                {
                    _interactor.CancelActiveInteraction();
                }

                state.HeldTime = 0.0f;
                state.HoldActivated = false;
                state.HoldThresholdReached = false;
            }

            if (Input.IsActionPressed(inputAction))
            {
                state.HeldTime += (float)delta;
                state.HoldThresholdReached =
                    state.HeldTime >= HoldThreshold
                    && HasMappedHold(inputAction);
                if (
                    !state.HoldActivated
                    && state.HoldThresholdReached
                    && TryBeginMappedHold(inputAction)
                )
                {
                    state.HoldActivated = true;
                }

                if (
                    state.HoldActivated
                    && _interactor.HasActiveInteraction
                )
                {
                    _interactor.UpdateActiveInteraction(delta);
                }
            }

            if (!justReleased)
            {
                continue;
            }

            if (wasHoldActivated)
            {
                if (!justPressed)
                {
                    _interactor.CancelActiveInteraction();
                }
            }
            else if (
                !wasHoldThresholdReached
                && !TryExecuteMappedTap(inputAction)
                && !HasMappedTapTarget(inputAction)
            )
            {
                _carrier.Throw();
            }

            if (!justPressed)
            {
                state.HeldTime = 0.0f;
                state.HoldActivated = false;
                state.HoldThresholdReached = false;
            }
        }
    }

    private bool TryExecuteMappedTap(StringName inputAction)
    {
        InteractionContext context = new(_actor, _carrier);
        foreach (InteractionInputBinding binding in InteractionInputs)
        {
            if (
                binding.InputAction == inputAction
                && binding.Trigger == InteractionInputTrigger.Tap
                && _interactor.TryExecute(binding.ActionIds, context)
            )
            {
                return true;
            }
        }

        return false;
    }

    private bool TryBeginMappedHold(StringName inputAction)
    {
        InteractionContext context = new(_actor, _carrier);
        foreach (InteractionInputBinding binding in InteractionInputs)
        {
            if (
                binding.InputAction == inputAction
                && binding.Trigger == InteractionInputTrigger.Hold
                && _interactor.TryBegin(binding.ActionIds, context)
            )
            {
                return true;
            }
        }

        return false;
    }

    private bool HasMappedTapTarget(StringName inputAction)
    {
        InteractionContext context = new(_actor, _carrier);
        foreach (InteractionInputBinding binding in InteractionInputs)
        {
            if (
                binding.InputAction == inputAction
                && binding.Trigger == InteractionInputTrigger.Tap
                && _interactor.HasTargetWithAction(
                    binding.ActionIds,
                    InteractionInputTrigger.Tap,
                    context
                )
            )
            {
                return true;
            }
        }

        return false;
    }

    private bool HasMappedHold(StringName inputAction)
    {
        foreach (InteractionInputBinding binding in InteractionInputs)
        {
            if (
                binding.InputAction == inputAction
                && binding.Trigger == InteractionInputTrigger.Hold
            )
            {
                return true;
            }
        }

        return false;
    }

    private void EnsureDefaultBindings()
    {
        if (InteractionInputs.Count > 0)
        {
            return;
        }

        InteractionInputs = CreateDefaultBindings();
    }

    private static Array<InteractionInputBinding> CreateDefaultBindings()
    {
        InteractionInputBinding tapBinding = new()
        {
            InputAction = DefaultInputAction,
            Trigger = InteractionInputTrigger.Tap,
        };
        tapBinding.ActionIds.Add(InteractionActionIds.Transfer);

        InteractionInputBinding holdBinding = new()
        {
            InputAction = DefaultInputAction,
            Trigger = InteractionInputTrigger.Hold,
        };
        holdBinding.ActionIds.Add(InteractionActionIds.Process);

        return new Array<InteractionInputBinding>
        {
            tapBinding,
            holdBinding,
        };
    }
}
