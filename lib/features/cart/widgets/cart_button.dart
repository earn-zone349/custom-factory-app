import 'package:flutter/material.dart';

import '../cart_controller.dart';
import '../cart_screen.dart';
import '../cart_scope.dart';

/// App bar cart icon with a badge showing how many products are in the cart.
class CartButton extends StatelessWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context) {
    final CartController? cart = CartScope.maybeOf(context);
    final int count = cart?.itemCount ?? 0;

    return IconButton(
      tooltip: 'Cart',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CartScreen()),
        );
      },
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}
