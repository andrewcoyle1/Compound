import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/food_model.dart';
import 'package:compound_models/src/nutrition_enums.dart';

/// What a recipe ingredient's amount is counted in (Swift
/// `IngredientAmountUnit`).
enum IngredientAmountUnit implements FirestoreEnum {
  /// `grams`.
  grams('grams'),

  /// `milliliters`.
  milliliters('milliliters'),

  /// `units`: whole items, which the nutrition maths counts as 100 g each.
  units('units');

  new(this.value);

  @override
  final String value;
}

/// Field names of a [RecipeIngredientModel], exactly as the Swift
/// `CodingKeys` spell them.
abstract final class RecipeIngredientModelKeys {
  /// `ingredient`: the whole food, copied into the recipe.
  static const ingredient = 'ingredient';

  /// `amount`.
  static const amount = 'amount';

  /// `unit`.
  static const unit = 'unit';

  /// Every field, in declaration order.
  static const List<String> all = [ingredient, amount, unit];
}

/// A food in a recipe, with how much of it is used (Swift
/// `RecipeIngredientModel`). The food is a copy, so editing or deleting it
/// in the library leaves the recipe as it was built.
class const RecipeIngredientModel({
  /// The food.
  required final FoodModel ingredient,

  /// How much of it.
  required final double amount,

  /// What [amount] is counted in.
  required final IngredientAmountUnit unit,
}) {
  /// Creates a [RecipeIngredientModel].
  this;

  /// [food] at [amount], counted in grams or, for a food measured by
  /// volume, millilitres, as Swift's initialiser picks when given no unit.
  factory forFood(FoodModel food, double amount) => RecipeIngredientModel(
    ingredient: food,
    amount: amount,
    unit: food.measurementMethod == MeasurementMethod.volume
        ? IngredientAmountUnit.milliliters
        : IngredientAmountUnit.grams,
  );

  /// Decodes as Swift does: an amount that is not finite reads as 0 and one
  /// outside 0 to [maximumAmount] is clamped into it, since the screens
  /// print it as a whole number.
  factory fromFirestore(Map<String, Object?> data) {
    final amount = readDouble(data[RecipeIngredientModelKeys.amount]);
    return RecipeIngredientModel(
      ingredient: FoodModel.fromFirestore(
        readMap(data[RecipeIngredientModelKeys.ingredient]),
      ),
      amount: amount.isFinite ? amount.clamp(0.0, maximumAmount) : 0,
      unit: enumFromValue(
        IngredientAmountUnit.values,
        data[RecipeIngredientModelKeys.unit]! as String,
      ),
    );
  }

  /// One tonne of one ingredient, the ceiling the entry fields impose.
  static const maximumAmount = 1000000.0;

  /// The id it is known by: its food's.
  String get id => ingredient.ingredientId;

  /// Its food's name.
  String get name => ingredient.name;

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore() => {
    RecipeIngredientModelKeys.ingredient: ingredient.toFirestore(),
    RecipeIngredientModelKeys.amount: amount,
    RecipeIngredientModelKeys.unit: unit.value,
  };
}

/// Field names of a [RecipeTemplateModel], exactly as the Swift
/// `CodingKeys` spell them.
abstract final class RecipeTemplateModelKeys {
  /// `recipe_id`, the recipe's id.
  static const recipeId = 'recipe_id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `name`.
  static const name = 'name';

  /// `description`.
  static const description = 'description';

  /// `image_url`.
  static const imageUrl = 'image_url';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// `date_modified`.
  static const dateModified = 'date_modified';

  /// `ingredients`.
  static const ingredients = 'ingredients';

  /// `click_count`.
  static const clickCount = 'click_count';

  /// `bookmark_count`.
  static const bookmarkCount = 'bookmark_count';

  /// `favourite_count`.
  static const favouriteCount = 'favourite_count';

  /// `serving_quantity`.
  static const servingQuantity = 'serving_quantity';

  /// `total_weight`.
  static const totalWeight = 'total_weight';

  /// `preparation_steps`.
  static const preparationSteps = 'preparation_steps';

  /// `prep_time_mins`.
  static const prepTimeMins = 'prep_time_mins';

  /// `cook_time_mins`.
  static const cookTimeMins = 'cook_time_mins';

  /// `source_url`.
  static const sourceUrl = 'source_url';

  /// Every field, in declaration order.
  static const List<String> all = [
    recipeId,
    authorId,
    name,
    description,
    imageUrl,
    dateCreated,
    dateModified,
    ingredients,
    clickCount,
    bookmarkCount,
    favouriteCount,
    servingQuantity,
    totalWeight,
    preparationSteps,
    prepTimeMins,
    cookTimeMins,
    sourceUrl,
  ];
}

/// A recipe in the user's library, at `users/{uid}/recipe_templates/
/// {recipeId}` (Swift `RecipeTemplateModel`): its ingredients make the
/// whole dish, which [servingQuantity] divides into servings.
class const RecipeTemplateModel({
  /// The recipe's id, stored as `recipe_id`.
  required final String recipeId,

  /// Its name.
  required final String name,

  /// When it was made.
  required final DateTime dateCreated,

  /// When it was last changed.
  required final DateTime dateModified,

  /// Its owner's user id. The rules refuse a write without it.
  final String? authorId,

  /// How it is described.
  final String? description,

  /// Its picture.
  final String? imageUrl,

  /// What goes into the whole dish.
  final List<RecipeIngredientModel> ingredients = const [],

  /// How often it has been opened.
  final int? clickCount,

  /// How often it has been bookmarked.
  final int? bookmarkCount,

  /// How often it has been made a favourite.
  final int? favouriteCount,

  /// How many servings the dish makes.
  final double servingQuantity = 1,

  /// Grams of the dish once prepared.
  final double? totalWeight,

  /// The method, a step at a time.
  final List<String> preparationSteps = const [],

  /// Minutes of preparation.
  final double? prepTimeMins,

  /// Minutes of cooking.
  final double? cookTimeMins,

  /// Where the recipe came from.
  final String? sourceUrl,
}) {
  /// Creates a [RecipeTemplateModel].
  this;

  /// Decodes as Swift does: a missing ingredient list or method reads as
  /// empty and a missing serving count as 1; everything else strictly.
  factory fromFirestore(Map<String, Object?> data) => RecipeTemplateModel(
    recipeId: data[RecipeTemplateModelKeys.recipeId]! as String,
    authorId: data[RecipeTemplateModelKeys.authorId] as String?,
    name: data[RecipeTemplateModelKeys.name]! as String,
    description: data[RecipeTemplateModelKeys.description] as String?,
    imageUrl: data[RecipeTemplateModelKeys.imageUrl] as String?,
    dateCreated: data[RecipeTemplateModelKeys.dateCreated]! as DateTime,
    dateModified: data[RecipeTemplateModelKeys.dateModified]! as DateTime,
    ingredients: [
      for (final ingredient
          in (data[RecipeTemplateModelKeys.ingredients] as List<Object?>?) ??
              const [])
        RecipeIngredientModel.fromFirestore(readMap(ingredient)),
    ],
    clickCount: readOptionalInt(data[RecipeTemplateModelKeys.clickCount]),
    bookmarkCount: readOptionalInt(data[RecipeTemplateModelKeys.bookmarkCount]),
    favouriteCount: readOptionalInt(
      data[RecipeTemplateModelKeys.favouriteCount],
    ),
    servingQuantity:
        readOptionalDouble(data[RecipeTemplateModelKeys.servingQuantity]) ?? 1,
    totalWeight: readOptionalDouble(data[RecipeTemplateModelKeys.totalWeight]),
    preparationSteps: data[RecipeTemplateModelKeys.preparationSteps] == null
        ? const []
        : readStringList(data[RecipeTemplateModelKeys.preparationSteps]),
    prepTimeMins: readOptionalDouble(
      data[RecipeTemplateModelKeys.prepTimeMins],
    ),
    cookTimeMins: readOptionalDouble(
      data[RecipeTemplateModelKeys.cookTimeMins],
    ),
    sourceUrl: data[RecipeTemplateModelKeys.sourceUrl] as String?,
  );

  /// The Firestore-shaped map Swift writes, a null field left out.
  Map<String, Object?> toFirestore() => {
    RecipeTemplateModelKeys.recipeId: recipeId,
    RecipeTemplateModelKeys.authorId: ?authorId,
    RecipeTemplateModelKeys.name: name,
    RecipeTemplateModelKeys.description: ?description,
    RecipeTemplateModelKeys.imageUrl: ?imageUrl,
    RecipeTemplateModelKeys.dateCreated: dateCreated,
    RecipeTemplateModelKeys.dateModified: dateModified,
    RecipeTemplateModelKeys.ingredients: [
      for (final ingredient in ingredients) ingredient.toFirestore(),
    ],
    RecipeTemplateModelKeys.clickCount: ?clickCount,
    RecipeTemplateModelKeys.bookmarkCount: ?bookmarkCount,
    RecipeTemplateModelKeys.favouriteCount: ?favouriteCount,
    RecipeTemplateModelKeys.servingQuantity: servingQuantity,
    RecipeTemplateModelKeys.totalWeight: ?totalWeight,
    RecipeTemplateModelKeys.preparationSteps: preparationSteps,
    RecipeTemplateModelKeys.prepTimeMins: ?prepTimeMins,
    RecipeTemplateModelKeys.cookTimeMins: ?cookTimeMins,
    RecipeTemplateModelKeys.sourceUrl: ?sourceUrl,
  };
}
