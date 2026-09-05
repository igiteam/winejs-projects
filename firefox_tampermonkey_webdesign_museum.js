// ==UserScript==
// @name         Web Design Museum - Cleaner
// @namespace    http://tampermonkey.net/
// @version      1.4
// @description  Remove footer, overlays, ads, rail elements, and iframes from Web Design Museum & open article links in new tab
// @author       You
// @match        https://www.webdesignmuseum.org/*
// @icon         https://www.webdesignmuseum.org/wp-content/themes/webdesignmuseum/favicons/favicon-32x32.png
// @grant        none
// @run-at       document-start
// ==/UserScript==

(function() {
    'use strict';

    // Remove #google_vignette from URL to prevent interstitial ad
    if (window.location.hash === '#google_vignette') {
        history.replaceState(null, null, window.location.pathname + window.location.search);
    }

    // Function to remove iframes (new)
    function removeIframes() {
        // Remove all iframes
        const iframes = document.querySelectorAll('iframe');
        iframes.forEach(iframe => {
            // Skip any essential iframes if needed (like for video content)
            const src = iframe.src || '';
            // Keep YouTube/Vimeo embeds if they're actual article content
            if (src.includes('youtube.com') || src.includes('vimeo.com') || src.includes('player.vimeo')) {
                console.log('Preserved video iframe:', src);
                return;
            }
            // Remove all other iframes (ads, trackers, etc.)
            iframe.remove();
            console.log('Removed iframe:', src || 'no src attribute');
        });

        // Also target specific suspicious iframe containers
        const suspiciousFrames = document.querySelectorAll('[class*="ad-frame"], [id*="ad-frame"], [class*="google_ads"], [id*="google_ads"]');
        suspiciousFrames.forEach(frame => {
            frame.remove();
            console.log('Removed suspicious ad frame');
        });
    }

    // Function to add target="_blank" to article links
    function addTargetBlankToArticles() {
        // Target all article elements and add target="_blank" to their anchor tags
        const articles = document.querySelectorAll('article.article a');
        articles.forEach(link => {
            if (!link.hasAttribute('target') || link.getAttribute('target') !== '_blank') {
                link.setAttribute('target', '_blank');
                console.log('Added target="_blank" to article link:', link.href);
            }
        });

        // Also catch any article links that might be structured differently
        const articleLinks = document.querySelectorAll('.article a, article a, [class*="article"] a');
        articleLinks.forEach(link => {
            // Only apply if the link contains an image or h2 (typical article structure)
            if (link.querySelector('img') || link.querySelector('h2')) {
                if (!link.hasAttribute('target') || link.getAttribute('target') !== '_blank') {
                    link.setAttribute('target', '_blank');
                    console.log('Added target="_blank" to article-style link:', link.href);
                }
            }
        });
    }

    // Function to remove elements by class name
    function removeElementsByClass(className) {
        const elements = document.querySelectorAll(`.${className}`);
        elements.forEach(element => {
            element.remove();
            console.log(`Removed element with class: ${className}`);
        });
    }

    // Function to remove elements by ID
    function removeElementsById(id) {
        const element = document.getElementById(id);
        if (element) {
            element.remove();
            console.log(`Removed element with ID: ${id}`);
        }
    }

    // Specifically target mys-wrapper with multiple approaches
    function killMysWrapper() {
        // Remove by class
        const mysClassElements = document.querySelectorAll('.mys-wrapper');
        mysClassElements.forEach(element => {
            element.remove();
            console.log('Removed .mys-wrapper element');
        });

        // Remove by ID (in case it has ID too)
        const mysIdElement = document.getElementById('mys-wrapper');
        if (mysIdElement) {
            mysIdElement.remove();
            console.log('Removed #mys-wrapper element');
        }

        // Also look for any iframes or containers that might contain "mys" in their class
        const possibleMysElements = document.querySelectorAll('[class*="mys"], [id*="mys"]');
        possibleMysElements.forEach(element => {
            if (element.className.includes('mys') || element.id.includes('mys')) {
                // Check if it's likely an ad wrapper (contains ads or has typical ad sizes)
                if (element.innerText.includes('ad') || element.innerText.includes('sponsored') ||
                    element.clientHeight <= 250 || element.clientWidth <= 300) {
                    element.remove();
                    console.log('Removed suspected mys-related element');
                }
            }
        });
    }

    // Function to remove elements (runs immediately and after DOM changes)
    function removeTargetElements() {
        // Remove iframes (NEW)
        removeIframes();

        // Remove by class
        removeElementsByClass('footer');
        removeElementsByClass('wpc-filters-overlay');
        removeElementsByClass('ima-sdk-frame');
        removeElementsByClass('sidebar');
        removeElementsByClass('ad_position_box');
        removeElementsByClass('videoAdUi');
        removeElementsByClass('breadcrumbs');
        removeElementsByClass('header');
        removeElementsByClass('share');


        // Remove by ID
        removeElementsById('adBanner');
        removeElementsById('pw-oop-bottom_rail');
        removeElementsById('pw-oop-left_rail');
        removeElementsById('pw-incontent');

        // Kill mys-wrapper specifically
        killMysWrapper();

        // Add target="_blank" to article links
        addTargetBlankToArticles();
    }

    // Run immediately
    removeTargetElements();

    // Use a more aggressive observer with specific configuration
    const observer = new MutationObserver(function(mutations) {
        let needsCleanup = false;
        let needsLinkUpdate = false;

        // Check if any of the mutations added elements we care about
        mutations.forEach(mutation => {
            if (mutation.addedNodes.length) {
                mutation.addedNodes.forEach(node => {
                    if (node.nodeType === 1) { // Element node
                        // Check for iframes (NEW)
                        if (node.tagName === 'IFRAME') {
                            needsCleanup = true;
                        }
                        if (node.querySelectorAll) {
                            if (node.querySelectorAll('iframe').length > 0) {
                                needsCleanup = true;
                            }
                        }
                        if (node.classList && (node.classList.contains('mys-wrapper') ||
                            node.id === 'mys-wrapper' ||
                            (node.className && node.className.includes('mys')) ||
                            (node.id && node.id.includes('mys')))) {
                            needsCleanup = true;
                        }
                        // Check if new article links were added
                        if (node.querySelectorAll && (node.querySelectorAll('article.article a').length > 0)) {
                            needsLinkUpdate = true;
                        }
                    }
                });
            }
        });

        if (needsCleanup) {
            removeTargetElements();
        } else {
            // Still run periodically to catch any that might be missed
            removeTargetElements();
        }

        // Always check for new article links
        if (needsLinkUpdate) {
            addTargetBlankToArticles();
        }
    });

    // Start observing once the DOM is ready
    if (document.body) {
        observer.observe(document.body, {
            childList: true,
            subtree: true,
            attributes: true, // Watch for attribute changes too
            attributeFilter: ['class', 'id', 'src'] // Added 'src' to watch for iframe src changes
        });
    } else {
        document.addEventListener('DOMContentLoaded', function() {
            observer.observe(document.body, {
                childList: true,
                subtree: true,
                attributes: true,
                attributeFilter: ['class', 'id', 'src']
            });
        });
    }

    // Extra fallback: Run cleanup every 2 seconds for 10 seconds (catch stubborn delayed ads)
    let runCount = 0;
    const interval = setInterval(() => {
        removeTargetElements();
        runCount++;
        if (runCount >= 10) { // Stop after 20 seconds
            clearInterval(interval);
        }
    }, 2000);

})();