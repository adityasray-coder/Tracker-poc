/**
 * Horizontally scrollable list of product cards.
 */

import React from 'react';
import {ScrollView, StyleSheet, Text, View, ViewStyle} from 'react-native';
import ProductCard, {ProductItem} from './ProductCard';

export interface ProductListProps {
  title: string;
  items: ProductItem[];
  surfaceStyle: ViewStyle;
  mutedColor: string;
  textColor: string;
  accentColor?: string;
  cardBorderColor?: string;
  onImpression?: (itemId: string) => void;
}

function ProductList({
  title,
  items,
  surfaceStyle,
  mutedColor,
  textColor,
  accentColor,
  cardBorderColor,
  onImpression,
}: ProductListProps): JSX.Element {
  return (
    <View style={styles.body}>
      <Text style={[styles.sectionTitle, {color: textColor}]}>{title}</Text>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.horizontalListContent}
        style={styles.horizontalList}>
        {items.map(item => (
          <ProductCard
            key={item.id}
            item={item}
            surfaceStyle={surfaceStyle}
            mutedColor={mutedColor}
            textColor={textColor}
            accentColor={accentColor}
            cardBorderColor={cardBorderColor}
            onAppear={onImpression}
          />
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  body: {
    flex: 1,
    paddingTop: 20,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: '700',
    paddingHorizontal: 20,
    marginBottom: 16,
    letterSpacing: 0.3,
  },
  horizontalList: {
    flexGrow: 0,
  },
  horizontalListContent: {
    paddingHorizontal: 20,
    paddingBottom: 28,
  },
});

export default ProductList;
