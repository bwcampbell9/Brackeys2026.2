using System;
using Godot;
using Godot.Collections;

[Flags]
public enum CustomerRequestOptions
{
    None = 0,
    Baby = 1 << 0,
    Carrot = 1 << 1,
    CarrotSoup = 1 << 2,
    ChoppedCarrots = 1 << 3,
    ChoppedPotatoes = 1 << 4,
    DubiousSoup = 1 << 5,
    Knife = 1 << 6,
    Potato = 1 << 7,
    PotatoSoup = 1 << 8,
    RecipeBook = 1 << 9,
    BakedChoppedCarrots = 1 << 10,
    BakedChoppedPotatoes = 1 << 11,
    BakedChoppedCarrotsAndPotatoes = 1 << 12,
    CarrotAndPotatoSoup = 1 << 13,
    BakedPotato = 1 << 14,
}

public partial class CustomerOrderConfiguration : CharacterBody2D
{
    private const CustomerRequestOptions KnownRequests =
        CustomerRequestOptions.Baby
        | CustomerRequestOptions.Carrot
        | CustomerRequestOptions.CarrotSoup
        | CustomerRequestOptions.ChoppedCarrots
        | CustomerRequestOptions.ChoppedPotatoes
        | CustomerRequestOptions.DubiousSoup
        | CustomerRequestOptions.Knife
        | CustomerRequestOptions.Potato
        | CustomerRequestOptions.PotatoSoup
        | CustomerRequestOptions.RecipeBook
        | CustomerRequestOptions.BakedChoppedCarrots
        | CustomerRequestOptions.BakedChoppedPotatoes
        | CustomerRequestOptions.BakedChoppedCarrotsAndPotatoes
        | CustomerRequestOptions.CarrotAndPotatoSoup
        | CustomerRequestOptions.BakedPotato;

    private static readonly RequestDefinition[] RequestDefinitions =
    [
        new(CustomerRequestOptions.Baby, "res://resources/items/baby.tres"),
        new(CustomerRequestOptions.Carrot, "res://resources/items/carrot.tres"),
        new(
            CustomerRequestOptions.CarrotSoup,
            "res://resources/items/carrot_soup.tres"
        ),
        new(
            CustomerRequestOptions.ChoppedCarrots,
            "res://resources/items/chopped_carrots.tres"
        ),
        new(
            CustomerRequestOptions.ChoppedPotatoes,
            "res://resources/items/chopped_potatoes.tres"
        ),
        new(
            CustomerRequestOptions.DubiousSoup,
            "res://resources/items/dubious_soup.tres"
        ),
        new(CustomerRequestOptions.Knife, "res://resources/items/knife.tres"),
        new(CustomerRequestOptions.Potato, "res://resources/items/potato.tres"),
        new(
            CustomerRequestOptions.PotatoSoup,
            "res://resources/items/potato_soup.tres"
        ),
        new(
            CustomerRequestOptions.RecipeBook,
            "res://resources/items/recipe_book.tres"
        ),
        new(
            CustomerRequestOptions.BakedChoppedCarrots,
            "res://resources/items/baked_chopped_carrots.tres"
        ),
        new(
            CustomerRequestOptions.BakedChoppedPotatoes,
            "res://resources/items/baked_chopped_potatoes.tres"
        ),
        new(
            CustomerRequestOptions.BakedChoppedCarrotsAndPotatoes,
            "res://resources/items/baked_chopped_vegetables.tres"
        ),
        new(
            CustomerRequestOptions.CarrotAndPotatoSoup,
            "res://resources/items/carrot_potato_soup.tres"
        ),
        new(
            CustomerRequestOptions.BakedPotato,
            "res://resources/items/baked_potato.tres"
        ),
    ];

    [ExportGroup("Customer Orders")]
    [Export]
    public CustomerRequestOptions PossibleRequests { get; set; } =
        CustomerRequestOptions.ChoppedPotatoes;

    [Export(PropertyHint.Range, "0,300,0.5,or_greater,suffix:s")]
    public float MinimumRequestCooldownSeconds { get; set; } = 1.0f;

    [Export(PropertyHint.Range, "0,300,0.5,or_greater,suffix:s")]
    public float MaximumRequestCooldownSeconds { get; set; } = 5.0f;

    [Export(PropertyHint.Range, "0.1,300,0.5,or_greater,suffix:s")]
    public float OrderDurationSeconds { get; set; } = 45.0f;

    [ExportGroup("Dependencies")]
    [Export]
    public NodePath TaskPublisherPath { get; set; } =
        new("WorkstationTaskPublisher");

    public override void _Ready()
    {
        if (PossibleRequests == CustomerRequestOptions.None)
        {
            throw new InvalidOperationException(
                $"{Name} must allow at least one customer request."
            );
        }
        if ((PossibleRequests & ~KnownRequests) != 0)
        {
            throw new InvalidOperationException(
                $"{Name} has an unknown customer request option."
            );
        }
        if (
            MinimumRequestCooldownSeconds < 0.0f
            || MaximumRequestCooldownSeconds < MinimumRequestCooldownSeconds
        )
        {
            throw new InvalidOperationException(
                $"{Name} requires a non-negative customer request cooldown "
                    + "range whose maximum is at least its minimum."
            );
        }

        WorkstationTaskPublisher publisher =
            GetNodeOrNull<WorkstationTaskPublisher>(TaskPublisherPath)
            ?? throw new InvalidOperationException(
                $"{Name} requires a WorkstationTaskPublisher."
            );

        Array<PickupItemDefinition> requests = new();
        foreach (RequestDefinition definition in RequestDefinitions)
        {
            if (!PossibleRequests.HasFlag(definition.Option))
            {
                continue;
            }

            PickupItemDefinition request =
                ResourceLoader.Load<PickupItemDefinition>(
                    definition.ResourcePath
                )
                ?? throw new InvalidOperationException(
                    $"Could not load customer request '{definition.ResourcePath}'."
                );
            requests.Add(request);
        }

        publisher.ConfigureCustomerOrders(
            requests,
            MinimumRequestCooldownSeconds,
            MaximumRequestCooldownSeconds,
            OrderDurationSeconds
        );
    }

    private readonly struct RequestDefinition
    {
        public RequestDefinition(
            CustomerRequestOptions option,
            string resourcePath
        )
        {
            Option = option;
            ResourcePath = resourcePath;
        }

        public CustomerRequestOptions Option { get; }

        public string ResourcePath { get; }
    }
}
