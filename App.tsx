/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import React, {useState} from 'react';
import {
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  useColorScheme,
  View,
  Pressable,
  Platform,
} from 'react-native';

import ProductList from './components/ProductList';
import type {ProductItem} from './components/ProductCard';

const TAB_LABELS = ['Home', 'Explore', 'Saved', 'Profile'];

const PALETTE = {
  light: {
    background: '#F1F5F9',
    surface: '#FFFFFF',
    text: '#0F172A',
    muted: '#64748B',
    accent: '#6366F1',
    tabInactive: '#94A3B8',
    cardBorder: '#E2E8F0',
  },
  dark: {
    background: '#0F172A',
    surface: '#1E293B',
    text: '#F8FAFC',
    muted: '#94A3B8',
    accent: '#818CF8',
    tabInactive: '#64748B',
    cardBorder: '#334155',
  },
};

// Sample data for the horizontal list
const LIST_ITEMS: ProductItem[] = Array.from({length: 5}, (_, i) => ({
  id: String(i + 1),
  title: `Item ${i + 1}`,
  subtitle: `Description for item ${i + 1}`,
}));

function App(): JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';
  const [activeTab, setActiveTab] = useState(0);
  const [impressionCounts, setImpressionCounts] = useState<Record<string, number>>({});
  const colors = isDarkMode ? PALETTE.dark : PALETTE.light;

  const handleImpression = (itemId: string) => {
    setImpressionCounts(prev => {
      const next = (prev[itemId] ?? 0) + 1;
      const nextState = {...prev, [itemId]: next};
      console.log(`[Impression] item ${itemId} | count: ${next}`);
      return nextState;
    });
  };

  return (
    <SafeAreaView style={[styles.container, {backgroundColor: colors.background}]}>
      <StatusBar
        barStyle={isDarkMode ? 'light-content' : 'dark-content'}
        backgroundColor={colors.background}
      />

      <View style={[styles.tabBar, {backgroundColor: colors.surface}]}>
        {TAB_LABELS.map((label, index) => (
          <Pressable
            key={label}
            style={({pressed}) => [
              styles.tab,
              activeTab === index && {
                backgroundColor: colors.accent,
                ...(Platform.OS === 'ios' && styles.tabActiveShadow),
              },
              pressed && {opacity: 0.9},
            ]}
            onPress={() => setActiveTab(index)}>
            <Text
              style={[
                styles.tabLabel,
                {
                  color: activeTab === index ? '#FFFFFF' : colors.tabInactive,
                },
              ]}>
              {label}
            </Text>
          </Pressable>
        ))}
      </View>

      <ScrollView
        style={[styles.bodyWrapper, {backgroundColor: colors.background}]}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}>
        <Text style={[styles.loremText, {color: colors.text}]}>
          Lorem ipsum dolor sit amet, consectetur adipiscing elit. 
          Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. 
          Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. 
        </Text>
        
        <ProductList
          title={TAB_LABELS[activeTab]}
          items={LIST_ITEMS}
          surfaceStyle={{backgroundColor: colors.surface}}
          mutedColor={colors.muted}
          textColor={colors.text}
          accentColor={colors.accent}
          cardBorderColor={colors.cardBorder}
          onImpression={handleImpression}
        />        
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  tabBar: {
    flexDirection: 'row',
    paddingHorizontal: 10,
    paddingVertical: 10,
    gap: 10,
    ...Platform.select({
      ios: {
        shadowColor: '#000',
        shadowOffset: {width: 0, height: 2},
        shadowOpacity: 0.06,
        shadowRadius: 4,
      },
      android: {elevation: 3},
    }),
  },
  tab: {
    flex: 1,
    paddingVertical: 12,
    paddingHorizontal: 14,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tabActiveShadow: {
    shadowColor: '#6366F1',
    shadowOffset: {width: 0, height: 2},
    shadowOpacity: 0.3,
    shadowRadius: 4,
  },
  tabLabel: {
    fontSize: 14,
    fontWeight: '600',
  },
  bodyWrapper: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
    paddingBottom: 24,
  },
  loremText: {
    fontSize: 50,
    paddingHorizontal: 20,
    paddingTop: 20,
    paddingBottom: 24,
    lineHeight: 60,
  },
});

export default App;
