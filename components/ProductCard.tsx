/**
 * Single product/item card for the horizontal list.
 * Uses native MyNativeView (SwiftUI .onAppear); the native side only fires when the card is in the viewport.
 */

import React from 'react';
import {Platform, StyleSheet, Text, View, ViewStyle} from 'react-native';
import MyNativeView from './native/MyNativeViewNativeComponent';

const CARD_WIDTH = 168;
const CARD_MARGIN = 14;

export interface ProductItem {
  id: string;
  title: string;
  subtitle: string;
}

export interface ProductCardProps {
  item: ProductItem;
  surfaceStyle: ViewStyle;
  mutedColor: string;
  textColor: string;
  accentColor?: string;
  cardBorderColor?: string;
  onAppear?: (itemId: string) => void;
}

function ProductCard({
  item,
  surfaceStyle,
  mutedColor,
  textColor,
  accentColor,
  cardBorderColor,
  onAppear,
}: ProductCardProps): JSX.Element {
  const borderColor = cardBorderColor ?? mutedColor;
  const thumbColor = accentColor ?? mutedColor;

  return (
    <MyNativeView
      style={[
        styles.card,
        surfaceStyle,
        {borderColor},
        Platform.OS === 'ios' ? styles.cardShadowIos : styles.cardShadowAndroid,
      ]}
      onNativeAppear={() => {
        onAppear?.(item.id);
      }}>
      <View style={[styles.cardThumb, {backgroundColor: thumbColor}]} />
      <Text style={[styles.cardTitle, {color: textColor}]} numberOfLines={1}>
        {item.title}
      </Text>
      <Text style={[styles.cardSubtitle, {color: mutedColor}]} numberOfLines={2}>
        {item.subtitle}
      </Text>
    </MyNativeView>
  );
}

const styles = StyleSheet.create({
  card: {
    width: CARD_WIDTH,
    marginRight: CARD_MARGIN,
    padding: 14,
    borderRadius: 16,
    borderWidth: 1,
  },
  cardShadowIos: {
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 4},
    shadowOpacity: 0.08,
    shadowRadius: 8,
  },
  cardShadowAndroid: {
    elevation: 4,
  },
  cardThumb: {
    width: '100%',
    aspectRatio: 1,
    borderRadius: 12,
    marginBottom: 10,
    opacity: 0.85,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 4,
  },
  cardSubtitle: {
    fontSize: 13,
    lineHeight: 18,
    opacity: 0.9,
  },
});

export default ProductCard;
