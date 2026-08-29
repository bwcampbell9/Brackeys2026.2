using Godot;

public interface IBodyPushReceiver
{
    void OnBodyPushed();
}

public partial class BodyPusher : Node
{
    private Vector2 _externalVelocity;

    [Export(PropertyHint.Range, "0,1,0.05")]
    public float CharacterMotionTransfer { get; set; } = 1.0f;

    [Export(PropertyHint.Range, "0,1,0.05")]
    public float RigidBodyVelocityTransfer { get; set; } = 1.0f;

    [Export(PropertyHint.Range, "1,100,1,or_greater")]
    public float PushDamping { get; set; } = 20.0f;

    public void MoveAndPush(
        CharacterBody2D actor,
        Vector2 requestedVelocity,
        double delta
    )
    {
        Vector2 movementVelocity = requestedVelocity + _externalVelocity;
        actor.Velocity = movementVelocity;
        actor.MoveAndSlide();

        for (int index = 0; index < actor.GetSlideCollisionCount(); index++)
        {
            KinematicCollision2D collision = actor.GetSlideCollision(index);
            Vector2 pushDirection = -collision.GetNormal();
            if (pushDirection.IsZeroApprox())
            {
                continue;
            }

            switch (collision.GetCollider())
            {
                case RigidBody2D rigidBody when !rigidBody.Freeze:
                    PushRigidBody(
                        rigidBody,
                        movementVelocity,
                        pushDirection
                    );
                    break;
                case CharacterBody2D characterBody
                    when characterBody != actor:
                    PushCharacterBody(
                        characterBody,
                        movementVelocity,
                        pushDirection
                    );
                    break;
            }
        }

        _externalVelocity *= Mathf.Exp(-PushDamping * (float)delta);
        if (_externalVelocity.LengthSquared() < 0.01f)
        {
            _externalVelocity = Vector2.Zero;
        }
    }

    private void PushRigidBody(
        RigidBody2D body,
        Vector2 requestedVelocity,
        Vector2 pushDirection
    )
    {
        float targetSpeed =
            Mathf.Max(0.0f, requestedVelocity.Dot(pushDirection))
            * RigidBodyVelocityTransfer;
        float speedChange = targetSpeed
            - body.LinearVelocity.Dot(pushDirection);
        if (speedChange <= 0.0f)
        {
            return;
        }

        if (body is IBodyPushReceiver receiver)
        {
            receiver.OnBodyPushed();
        }
        body.ApplyCentralImpulse(pushDirection * speedChange * body.Mass);
    }

    private void PushCharacterBody(
        CharacterBody2D body,
        Vector2 requestedVelocity,
        Vector2 pushDirection
    )
    {
        BodyPusher? bodyPusher = body.GetNodeOrNull<BodyPusher>(
            "BodyPusher"
        );
        if (bodyPusher is null)
        {
            return;
        }

        float pushSpeed =
            Mathf.Max(0.0f, requestedVelocity.Dot(pushDirection))
            * CharacterMotionTransfer;
        if (pushSpeed <= 0.0f)
        {
            return;
        }

        bodyPusher.ReceivePush(pushDirection * pushSpeed);
    }

    private void ReceivePush(Vector2 velocity)
    {
        Vector2 pushDirection = velocity.Normalized();
        float speedChange =
            velocity.Length() - _externalVelocity.Dot(pushDirection);
        if (speedChange <= 0.0f)
        {
            return;
        }

        _externalVelocity += pushDirection * speedChange;
    }
}
