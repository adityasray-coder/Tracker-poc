/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import React, {useState} from 'react';
import {
  SafeAreaView,
  StatusBar,
  StyleSheet,
  Text,
  useColorScheme,
  View,
  Pressable,
} from 'react-native';

import {Colors} from 'react-native/Libraries/NewAppScreen';
import ProductList from './components/ProductList';
import type {ProductItem} from './components/ProductCard';

const TAB_LABELS = ['Home', 'Explore', 'Saved', 'Profile'];

// Sample data for the horizontal list
const INITIAL_ITEMS: ProductItem[] = Array.from({length: 12}, (_, i) => ({
  id: String(i + 1),
  title: `Item ${i + 1}`,
  subtitle: `Description for item ${i + 1}`,
  impressionCount: 0,
}));

function App(): JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';
  const [activeTab, setActiveTab] = useState(0);
  const [items, setItems] = useState<ProductItem[]>(INITIAL_ITEMS);

  const handleImpression = (itemId: string) => {
    setItems(prev => {
      const next = prev.map(p =>
        p.id === itemId ? {...p, impressionCount: p.impressionCount + 1} : p,
      );
      const product = next.find(p => p.id === itemId);
      const newCount = product?.impressionCount ?? 0;
      console.log(
        `Product ${itemId}: visibility criteria met, impression count updated to ${newCount}`,
      );
      return next;
    });
  };

  const backgroundStyle = {
    backgroundColor: isDarkMode ? Colors.darker : Colors.lighter,
  };
  const surfaceStyle = {
    backgroundColor: isDarkMode ? Colors.black : Colors.white,
  };
  const textColor = isDarkMode ? Colors.white : Colors.black;
  const mutedColor = isDarkMode ? Colors.light : Colors.dark;
  const tabActiveBg = isDarkMode ? Colors.light : Colors.dark;
  const tabInactiveBg = 'transparent';
  const tabActiveText = isDarkMode ? Colors.black : Colors.white;
  const tabInactiveText = mutedColor;

  return (
    <SafeAreaView style={[styles.container, backgroundStyle]}>
      <StatusBar
        barStyle={isDarkMode ? 'light-content' : 'dark-content'}
        backgroundColor={backgroundStyle.backgroundColor}
      />

      {/* Top tabs */}
      <View style={[styles.tabBar, surfaceStyle]}>
        {TAB_LABELS.map((label, index) => (
          <Pressable
            key={label}
            style={[
              styles.tab,
              activeTab === index && {
                backgroundColor: tabActiveBg,
              },
            ]}
            onPress={() => setActiveTab(index)}>
            <Text
              style={[
                styles.tabLabel,
                {
                  color: activeTab === index ? tabActiveText : tabInactiveText,
                },
              ]}>
              {label}
            </Text>
          </Pressable>
        ))}
      </View>

      {/* Horizontally scrollable list */}
      <View style={[styles.bodyWrapper, backgroundStyle]}>
        <ProductList
          title={TAB_LABELS[activeTab]}
          items={items}
          surfaceStyle={surfaceStyle}
          mutedColor={mutedColor}
          textColor={textColor}
          onImpression={handleImpression}
        />
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  tabBar: {
    flexDirection: 'row',
    paddingHorizontal: 8,
    paddingVertical: 8,
    gap: 8,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: 'rgba(0,0,0,0.1)',
  },
  tab: {
    flex: 1,
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tabLabel: {
    fontSize: 14,
    fontWeight: '600',
  },
  bodyWrapper: {
    flex: 1,
  },
});

export default App;
