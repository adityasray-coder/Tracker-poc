/**
 * Horizontally scrollable list of product cards.
 */

import React, {useRef, useCallback} from 'react';
import {
  NativeScrollEvent,
  NativeSyntheticEvent,
  ScrollView,
  StyleSheet,
  Text,
  View,
  ViewStyle,
} from 'react-native';
import ProductCard, {ProductItem} from './ProductCard';

const VISIBILITY_THRESHOLD = 0.7;
const IMPRESSION_DURATION_MS = 2000;

export interface ProductListProps {
  title: string;
  items: ProductItem[];
  surfaceStyle: ViewStyle;
  mutedColor: string;
  textColor: string;
  onImpression: (itemId: string) => void;
}

interface CardLayout {
  x: number;
  width: number;
}

function ProductList({
  title,
  items,
  surfaceStyle,
  mutedColor,
  textColor,
  onImpression,
}: ProductListProps): JSX.Element {
  const scrollXRef = useRef(0);
  const containerWidthRef = useRef(0);
  const layoutByItemIdRef = useRef<Record<string, CardLayout>>({});
  const timersByItemIdRef = useRef<Record<string, ReturnType<typeof setTimeout>>>({});

  const checkVisibility = useCallback(() => {
    const scrollX = scrollXRef.current;
    const containerWidth = containerWidthRef.current;
    const layoutByItemId = layoutByItemIdRef.current;

    if (containerWidth <= 0) return;

    const viewportLeft = scrollX;
    const viewportRight = scrollX + containerWidth;

    items.forEach(item => {
      const layout = layoutByItemId[item.id];
      if (!layout) return;

      const {x: cardX, width: cardWidth} = layout;
      const cardRight = cardX + cardWidth;

      const visibleLeft = Math.max(viewportLeft, cardX);
      const visibleRight = Math.min(viewportRight, cardRight);
      const visibleWidth = Math.max(0, visibleRight - visibleLeft);
      const visibleRatio = cardWidth > 0 ? visibleWidth / cardWidth : 0;

      const timers = timersByItemIdRef.current;

      if (visibleRatio >= VISIBILITY_THRESHOLD) {
        if (!timers[item.id]) {
          timers[item.id] = setTimeout(() => {
            onImpression(item.id);
            delete timersByItemIdRef.current[item.id];
          }, IMPRESSION_DURATION_MS);
        }
      } else {
        if (timers[item.id]) {
          clearTimeout(timers[item.id]);
          delete timers[item.id];
        }
      }
    });
  }, [items, onImpression]);

  const handleScroll = useCallback(
    (e: NativeSyntheticEvent<NativeScrollEvent>) => {
      scrollXRef.current = e.nativeEvent.contentOffset.x;
      checkVisibility();
    },
    [checkVisibility],
  );

  const handleContainerLayout = useCallback(
    (e: {nativeEvent: {layout: {width: number}}}) => {
      containerWidthRef.current = e.nativeEvent.layout.width;
      checkVisibility();
    },
    [checkVisibility],
  );

  const handleCardLayout = useCallback(
    (itemId: string) => (e: {nativeEvent: {layout: {x: number; width: number}}}) => {
      const {x, width} = e.nativeEvent.layout;
      layoutByItemIdRef.current[itemId] = {x, width};
      checkVisibility();
    },
    [checkVisibility],
  );

  return (
    <View style={styles.body}>
      <Text style={[styles.sectionTitle, {color: textColor}]}>{title}</Text>
      <View style={styles.scrollWrapper} onLayout={handleContainerLayout}>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.horizontalListContent}
          style={styles.horizontalList}
          onScroll={handleScroll}
          scrollEventThrottle={100}>
          {items.map(item => (
            <View key={item.id} onLayout={handleCardLayout(item.id)}>
              <ProductCard
                item={item}
                surfaceStyle={surfaceStyle}
                mutedColor={mutedColor}
                textColor={textColor}
              />
            </View>
          ))}
        </ScrollView>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  body: {
    flex: 1,
    paddingTop: 16,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '600',
    paddingHorizontal: 20,
    marginBottom: 12,
  },
  scrollWrapper: {
    flex: 1,
  },
  horizontalList: {
    flexGrow: 0,
  },
  horizontalListContent: {
    paddingHorizontal: 20,
    paddingBottom: 24,
  },
});

export default ProductList;
