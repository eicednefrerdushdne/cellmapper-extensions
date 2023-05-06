// ==UserScript==
// @name         CellMapper Extensions
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  Some stuff to make mapping towers faster and easier.
// @author       eicednefrerdushdne
// @match        https://www.cellmapper.net/map*
// @icon         https://www.google.com/s2/favicons?domain=cellmapper.net
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    var scripts = [
        'https://cdn.jsdelivr.net/npm/prettier@2.8.2/parser-babel.js',
        'https://cdn.jsdelivr.net/npm/prettier@2.8.2/standalone.js'
    ];

    for (var src in scripts) {
        // Import javascript beautifier
        var script = document.createElement('script');
        script.type = 'text/javascript';
        script.src = scripts[src];
        document.head.appendChild(script);
    }

    select_interaction.getFeatures().on("add", function (e) {
        var marker = e.element; //the feature selected
        //console.log(e);
        //debugger;
        if (marker.get("name") != undefined) {
            var coordinates = marker.get('geometry').flatCoordinates;
            $.ajax({
                type: "GET",
                dataType: "json",
                url: "http://localhost:8080/enb/" + marker.get('MCC') + "/" + marker.get('MNC') + "/" + (marker.get('towerName') ?? marker.get('base')),
                xhrFields: {
                    withCredentials: false
                },
                success: function (data) {
                    var minMaxZoom = data.length < 40 ? 30 : 16.5;

                    resetCircleLayer(map, 'circleLayer', Math.max(16.5, minMaxZoom), '#3399CCC0');
                    resetCircleLayer(map, 'circleLayer150', Math.max(18, minMaxZoom), '#ff9900C0');
                    resetCircleLayer(map, 'circleLayer0', Math.max(50, minMaxZoom), '#ff3300C0');
                    for (var key in data) {
                        var p = data[key];
                        if (p.TAMeters != -1) {
                            if (p.TAMeters == 0) {
                                p.TAMeters = 15;
                                addCircle(map, 'circleLayer0', [p.Longitude, p.Latitude], p.TAMeters);
                            } else if (p.TAMeters == 150) {
                                addCircle(map, 'circleLayer150', [p.Longitude, p.Latitude], p.TAMeters);
                            } else {
                                addCircle(map, 'circleLayer', [p.Longitude, p.Latitude], p.TAMeters);
                            }
                        }
                    }
                }
            });
        }
    });

    window.circleLayers = []

    var beautifyFunction = function (func) {
        var functionContents = func.toString()

        if (functionContents.startsWith('function(')) {
            functionContents = 'function xyz' + functionContents.substr(8);
        }
        functionContents = prettier.format(functionContents, {
            parser: "babel",
            plugins: prettierPlugins,
        });
        var funcArgs = functionContents.substr(0, functionContents.indexOf(')'));
        funcArgs = funcArgs.substr(funcArgs.indexOf('(') + 1);
        funcArgs = funcArgs.split(',');
        functionContents = functionContents.substr(functionContents.indexOf('{') + 1, functionContents.lastIndexOf('}') - functionContents.indexOf('{') - 1);

        return { arguments: funcArgs, body: functionContents };
    }

    var resetCircleLayer = function (map, layerName, maxZoom, color) {
        var view = map.getView();
        var projection = view.getProjection();

        if (window[layerName]) {
            window.circleLayers.splice(window.circleLayers.indexOf(window[layerName]), 1);
            map.removeLayer(window[layerName]);

        }

        // Source and vector layer
        var vectorSource = new ol.source.Vector({
            projection: projection.code_
        });

        window[layerName] = new ol.layer.Vector({
            source: vectorSource,
            style: new ol.style.Style({
                fill: new ol.style.Fill({
                    color: 'rgba(255,255,255,0.0)'
                }),
                stroke: new ol.style.Stroke({
                    color: color,
                    width: 1.25
                }),
                renderBuffer: 1000
            })
        });

        if (typeof maxZoom !== 'number') {
            maxZoom = 16.5;
        }
        window[layerName].setMaxZoom(maxZoom);

        map.addLayer(window[layerName]);
        window.circleLayers.push(window[layerName]);
    }

    var addCircle = function (map, layerName, coordinates, radius) {
        var view = map.getView();
        var projection = view.getProjection();
        var resolutionAtEquator = view.getResolution();
        var center = map.getView().getCenter();
        var pointResolution = projection.getPointResolutionFunc_(resolutionAtEquator, center);
        var resolutionFactor = resolutionAtEquator / pointResolution;
        radius = (radius / ol.proj.Units.METERS_PER_UNIT.m) * resolutionFactor;

        // Translate the Latitude and Longitude to projection coordinates

        coordinates = ol.proj.fromLonLat(coordinates, projection)

        var circle = new ol.geom.Circle(coordinates, radius);
        var circleFeature = new ol.Feature(circle);

        // Source and vector layer
        var vectorSource = window[layerName].getSource();
        vectorSource.addFeature(circleFeature);

    }

    var waitForTrue = function (testFunction, callback) {
        if (testFunction() === true) {
            callback();
        } else {
            setTimeout(function () {
                waitForTrue(testFunction, callback);
            }, 100);
        }
    };

    // Copies a string to the clipboard. Must be called from within an
    // event handler such as click. May return false if it failed, but
    // this is not always possible. Browser support for Chrome 43+,
    // Firefox 42+, Safari 10+, Edge and Internet Explorer 10+.
    // Internet Explorer: The clipboard feature may be disabled by
    // an administrator. By default a prompt is shown the first
    // time the clipboard is used (per session).
    window.copyToClipboard = function (text) {
        if (window.clipboardData && window.clipboardData.setData) {
            // Internet Explorer-specific code path to prevent textarea being shown while dialog is visible.
            return window.clipboardData.setData("Text", text);

        }
        else if (document.queryCommandSupported && document.queryCommandSupported("copy")) {
            var textarea = document.createElement("textarea");
            textarea.textContent = text;
            textarea.style.position = "fixed";  // Prevent scrolling to bottom of page in Microsoft Edge.
            document.body.appendChild(textarea);
            textarea.select();
            try {
                return document.execCommand("copy");  // Security exception may be thrown by some browsers.
            }
            catch (ex) {
                console.warn("Copy to clipboard failed.", ex);
                return false;
            }
            finally {
                document.body.removeChild(textarea);
            }
        }
    }

    window.openGoogleEarth = function (mcc, mnc, rat, towerID) {
        var t = window.Towers.find(function (z) { return z.values_?.MCC == mcc && z.values_?.MNC == mnc && z.values_?.system == rat && z.values_?.towerName == towerID });
        if (t === undefined) {
            t = window.Towers.find(function (z) { return z.values_?.MCC == mcc && z.values_?.MNC == mnc && z.values_?.system == rat && z.values_?.name == towerID });
        }

        if(t === undefined) {
            console.error("Couldn't find " + mcc + "-" + mnc + " " + rat + " " + towerID + " in the window.Towers array");
            debugger;
            if(t === undefined) {return;};
        }

        // Translate the projection coordinates to Latitude and Longitude
        var coordinates = ol.proj.toLonLat(t.values_.geometry.flatCoordinates, map.getView().getProjection());

        $.ajax({
            type: "POST",
            url: "http://localhost:8080/openGoogleEarth",
            contentType: "application/json; charset=UTF-8",
            data: JSON.stringify({
                towerID:   towerID,
                rat:       t.values_.system,
                mcc:       t.values_.MCC,
                mnc:       t.values_.MNC,
                latitude:  coordinates[1],
                longitude: coordinates[0],
                verified:  t.values_.verified
            }),
            xhrFields: {
                withCredentials: false
            },
            success: function (data) {
            }
        });
    }

    window.setTowerMoverFilter = function () {

    }

    var improveContextMenu = function (map) {
        var listener = map.listeners_.contextmenu[0];
        var func = beautifyFunction(listener);
        var functionContents = func.body;

        var insertText = `'<a href="javascript:copyToClipboard(\\'' + o + ',' + n + '\\');">Copy Coordinates</a><br />'
                        + '<a href="http://www.antennasearch.com/HTML/search/search.php?address=' + o +'%2C+' + n + '" target="_blank" rel="noreferrer">Open in AntennaSearch.com</a><br />'
                        + `
        var searchText = `  a =`
        var startIndex = functionContents.indexOf(searchText)

        var newContents = functionContents.substr(0, startIndex + searchText.length) + insertText + functionContents.substr(startIndex + searchText.length);

        newContents = newContents.replace(new RegExp(`<a href="https://www.google.com/maps/@.*15z`, 's'), `<a href="https://www.google.com/maps/search/?api=1&query=' + o + "," + n + '"`)
        var newListener = new Function(func.arguments[0], newContents);
        map.listeners_.contextmenu[0] = newListener;
    }

    var improveShowBandTilesAndTowers = function () {
        var func = beautifyFunction(window.showBandTilesAndTowers);
        var functionContents = func.body;
        var newContents = functionContents;

        newContents = newContents.replace(`showTiles(MCC, MNC)`,
            `tilesEnabled && showTiles(MCC, MNC)`);

        var newfunc = new Function(func.arguments[0], newContents);
        window.showBandTilesAndTowers = newfunc;
    }

    var improveSideBarMenu = function () {

        var func = beautifyFunction(window.getBaseStation);
        var functionContents = func.body;

        var newContents = functionContents;

        var insertText = `<li><a href='#' onclick='openGoogleEarth(" + ` + func.arguments[0] + ` + ", " + ` + func.arguments[1] + ` + ", \\"" + netType + "\\", \\"" + (r?.towerAttributes?.TOWER_NAME ?? ` + func.arguments[3] + `) + "\\")'>Open in Google Earth</a></li>`
        var searchText = new RegExp(`<li><a href='#' onclick='HandleDeleteTower`, 's')
        var startIndex = newContents.search(searchText)

        newContents = newContents.substr(0, startIndex) + insertText + newContents.substr(startIndex);

        startIndex = newContents.search(new RegExp(`" \\+\\s+r.cells\\[w\\].PCI \\+`, 's'));
        insertText = `<a href='#' onclick='$(\\"#pcipsc_search\\").val(\\"" + r.cells[w].PCI + "\\");handlePCIPSCSearch();'>`

        newContents = newContents.substr(0, startIndex) + insertText + newContents.substr(startIndex);

        startIndex = newContents.search(new RegExp(`</td></tr>"\\),\\s+"LTE" == i &&`, 's'));
        insertText = `</a>`
        if (startIndex !== -1) {
            newContents = newContents.substr(0, startIndex) + insertText + newContents.substr(startIndex);
        }

        var newfunc = new Function(func.arguments[0], func.arguments[1], func.arguments[2], func.arguments[3], func.arguments[4], newContents);
        window.getBaseStation = newfunc;

    }

    var improveGetTowerOverrideHistory = function () {
        var func = beautifyFunction(window.getTowerOverrideHistory);
        var functionContents = func.body;


        functionContents = functionContents.replace(`+ ")'>View</a></td>";`,
            `+ ")'>(" + item['latitude'] + "," + item['longitude'] + ")</a><br /><a href='#' onclick='javascript:triggerTowerLocationConfirmation(\\"" + item['mcc'] + '", "' + item['mnc'] + '", "' + item['rat'] + '", "' + item['lac'] + '", "' + item['base'] + '", "' + item['latitude'] + '", "' + item['longitude'] + '"' + ")'>Restore this Location</a></td>";`);

        var newfunc = new Function(func.arguments[0], func.arguments[1], func.arguments[2], func.arguments[3], func.arguments[4], func.arguments[5], func.arguments[6], functionContents);
        window.getTowerOverrideHistory = newfunc;

    }

    window.togglingShowMineOnly = false;
    var fixtoggleshowMineOnly = function () {
        var func = beautifyFunction(window.toggleshowMineOnly);
        var functionContents = func.body;

        functionContents = `
        if(window.togglingShowMineOnly === true) {
          return;
        }
        var e = showMineOnly = !showMineOnly;
        ` + functionContents + `

        window.togglingShowMineOnly = true;
        $('#showMineOnly')[0].checked = showMineOnly;
        $('#showMineOnly2')[0].checked = showMineOnly;
        window.togglingShowMineOnly = false;
        `;

        var newfunc = new Function(functionContents);
        window.toggleshowMineOnly = newfunc;

    }

    window.togglingTrails = false;
    var fixToggleTrails = function () {
        var func = beautifyFunction(window.toggleTrails);
        var functionContents = func.body;

        functionContents = `
        if(window.togglingTrails === true) {
          return;
        }
        ` + functionContents + `

        window.togglingTrails = true;
        $('#doTrails')[0].checked = tilesEnabled;
        $('#doTrails2')[0].checked = tilesEnabled;
        window.togglingTrails = false;
        window.updateLinkback();
        `;

        var newfunc = new Function(functionContents);
        window.toggleTrails = newfunc;

    }

    window.togglingShowUnverifiedOnly = false;
    var fixToggleShowUnverifiedOnly = function () {
        var func = beautifyFunction(window.toggleShowUnverifiedOnly);
        var functionContents = func.body

        functionContents = `
        if(window.togglingShowUnverifiedOnly === true) {
          return;
        }

        window.togglingShowUnverifiedOnly = true;
        var value = window.showUnverifiedOnly = !window.showUnverifiedOnly;

        $('#showUnverifiedOnly')[0].checked = value;
        $('#showUnverifiedOnly2')[0].checked = value;
        window.togglingShowUnverifiedOnly = false;

        ` + functionContents;

        var newfunc = new Function(functionContents);
        window.toggleShowUnverifiedOnly = newfunc;

    }
    /*
    window.triggerTowerLocationConfirmation = function triggerTowerLocationConfirmation(inMCC, inMNC, inSystem, inLAC, inBase, latitude, longitude) {
        var tower = window.Towers.find(t => {return t.get('base') == inBase && t.get('MCC') == inMCC && t.get('MNC') == inMNC && t.get('system') == inSystem;});

        if(tower) {
            handleTowerMove(tower, latitude, longitude);
        }

    }*/
    window.onlyPrimaryTowers = false;
    window.smallcells = [];
    window.filterTowerMover = [];
    window.excludeFilterTowerMover = false;
    var fixRefreshTowers = function () {
        var func = beautifyFunction(window.refreshTowers);
        var functionContents = func.body;
        var newContents = functionContents;
        var insertText = `
			if(filterTowerMover.length !== 0) {
                if(undefined === Towers[e].get("towerMover")) {
                    t = false;
                } else if((filterTowerMover.indexOf(Towers[e].get("towerMover")) !== -1) === window.excludeFilterTowerMover) {
                    t = false;
                }
            }

            if(typeof filterIDs !== 'undefined' && filterIDs.length !== 0 && filterIDs.indexOf(Towers[e].get('base')) === -1) {
                t = false;
            }
/*
            if(window.onlyPrimaryTowers === true) {
                var bands = Towers[e].get('bands')
                if(!((bands.includes(12) || bands.includes(13)) && (bands.includes(2) || bands.includes(4) || bands.includes(66)))) {
                    t = false;
                }
            }*/
`
        var searchText = new RegExp(`try.+vectorSourceTowers`, 's');
        var startIndex = newContents.search(searchText)
        if (startIndex !== -1)
            newContents = newContents.substr(0, startIndex) + insertText + newContents.substr(startIndex);

        var newfunc = new Function(newContents);
        window.refreshTowers = newfunc;
    }

    var fixHandleTowerMove = function () {
        var func = beautifyFunction(window.handleTowerMove);
        var functionContents = func.body;
        functionContents = functionContents.substr(functionContents.indexOf('{') + 1, functionContents.lastIndexOf('}') - functionContents.indexOf('{') - 1)

        functionContents = functionContents.replace(`({delay:10000})`, `({delay:1000000, autohide: false})`)


        var newfunc = new Function(func.arguments[0], func.arguments[1], func.arguments[2], functionContents);
        window.handleTowerMove = newfunc;
    }


    var fixPCISearch = function () {
        var functionContents = beautifyFunction(window.handlePCIPSCSearch)

        var newContents = functionContents.body;
        var insertText = `
        var o = handleResponse(t);
			window.filterIDs = [];
            $.each(o, function(i,item){
                filterIDs.push(item.siteID);
            });
            refreshTowers();
`
        var search = new RegExp(`var o = handleResponse.+onEscape: !0 }\\);`, 's');

        newContents = newContents.replace(search, insertText);

        newContents = newContents.replace(`var e = $("#pcipsc_search").val();`,
            `  var e = $("#pcipsc_search").val();
   if(e === '') {
     window.filterIDs = [];
     refreshTowers();
     return;
   }`);

        var newfunc = new Function(newContents);
        window.handlePCIPSCSearch = newfunc;
    }

    window.toggleOnlyPrimaryTowers = function () {
        window.onlyPrimaryTowers = $('#onlyPrimaryTowers')[0].checked;
        refreshTowers();
    }

    // Modify the layer filter for the select interaction so it excludes the circle layers we've added.
    waitForTrue(function () { return map !== null && map.interactions.array_.some(el => { return el instanceof ol.interaction.Select }) },
        function () {
            var interaction = map.interactions.array_.find(el => { return el instanceof ol.interaction.Select });
            interaction.layerFilter_ = function (l) { return !window.circleLayers.includes(l); };
        });

    waitForTrue(function () { return window.prettier !== undefined && window.prettierPlugins !== undefined && window.prettierPlugins.babel !== undefined },
        function () {

            waitForTrue(function () { return map !== null && map.listeners_ !== null && map.listeners_.contextmenu !== null && map.listeners_.contextmenu[0] !== null },
                function () { improveContextMenu(window.map) });

            waitForTrue(function () { return window.toggleTrails !== undefined },
                function () {
                    fixToggleTrails();
                });

            waitForTrue(function () { return window.refreshTowers !== undefined },
                function () {
                    fixRefreshTowers();
                });

            waitForTrue(function () { return window.getBaseStation !== undefined },
                function () {
                    improveSideBarMenu();
                });

            waitForTrue(function () { return window.handleTowerMove !== undefined },
                function () {//fixHandleTowerMove();
                });

            waitForTrue(function () { return window.handlePCIPSCSearch !== undefined },
                function () {
                    fixPCISearch();
                });

            waitForTrue(function () { return window._renderUserStats !== undefined },
                function () {
                    window._renderUserStats = function (inUid, divName) {
                        $("#" + divName).append(" <a href='#' onclick='getUserHistory(" + inUid + ", 0)'><span title='" + ("Points: " + userCache[inUid].totalPoints + ", Cells: " + userCache[inUid].totalCells + ", Towers modified: " + userCache[inUid].totalLocatedTowers) + ", ID: " + inUid + "'>" + userCache[inUid].userName + "</span>" + (userCache[inUid].premium ? "<span title='Premium User' style='color: gold'>&#x2605;</span></a>" : ""));
                    };
                });

            waitForTrue(function () { return window.toggleshowMineOnly !== undefined },
                function () {
                    fixtoggleshowMineOnly();
                });

            waitForTrue(function () { return window.toggleShowUnverifiedOnly !== undefined },
                function () {
                    fixToggleShowUnverifiedOnly();
                });

            waitForTrue(function () { return window.getTowerOverrideHistory !== undefined },
                function () {
                    improveGetTowerOverrideHistory();
                });

            waitForTrue(function () { return window.showBandTilesAndTowers !== undefined },
                function () {
                    improveShowBandTilesAndTowers();
                });

            if (window.tilesEnabled === false) {
                waitForTrue(function () {
                    return window.tilesEnabled === false && map.getLayers().array_.some((function (t) { return null != t && null != t.get("name") && t.get("name") === "SignalTrails" }))
                }, function () {
                    window.clearLayer("SignalTrails");
                });
            }
        });

    // Add keyboard shortcuts
    function doc_keyUp(e) {

        // this would test for whichever key is 40 (down arrow) and the ctrl key at the same time
        if (e.altKey && e.key === 'p') {
            // call your function to do the thing
            $('#pcipsc_search').val('');
            window.handlePCIPSCSearch();
        }
    }
    // register the handler
    document.addEventListener('keyup', doc_keyUp, false);

    /*
    waitForTrue(function() {return $("#accountTable i.fa.caretIcon").length == 1},
                function() {
        $("#accountTable tr.collapsableSection").click();
    });

    waitForTrue(function() {return $("#tower_search").length == 1},
                function() {
        $("#towersearch tr.collapsedSection").click();
        $("#select_provider_table tr.collapsableSection").click();
        $("#filters tr.collapsedSection").click();
        $("#pcipscsearch tr.collapsedSection").click();

        $("#whatsnew").remove();
    });

    waitForTrue(function() {return $("#doLowAccuracy").length == 1},
                function() {
        $(`
        <tr><td width="50%">Small Cells</td>
        <td width="50%">
        <select onchange="refreshTowers();" id="filterSmallCells">
          <option value="AllTowers">All Towers</option>
          <option value="HideSmallCells" selected>Hide Small Cells</option>
          <option value="OnlySmallCells">Only Small Cells</option>
        </select>
        </td></tr>
        <tr>
            <td width="50%">Only Show Primary Towers</td>
            <td align="right"><input type="checkbox" id="onlyPrimaryTowers" onclick="toggleOnlyPrimaryTowers()"></td>
        </tr>
        `).insertBefore($('#doLowAccuracy').parents()[1]);
    });*/

    waitForTrue(function () { return $(".nav-link.nav-linkpage-scroll[href='https://cellmapper.freshdesk.com/']").length == 1 },
        function () {
            var supportLink = $(".nav-link.nav-linkpage-scroll[href='https://cellmapper.freshdesk.com/']").parent();
            $(`
        <li class="nav-item">
          <label class="nav-link nav-linkpage-scroll">
            <input id="showMineOnly2" class="nav-logos fas" type="checkbox" onclick="toggleshowMineOnly()" />
            Show Mine Only
          </label>

        </li>

        <li class="nav-item">
          <label class="nav-link nav-linkpage-scroll">
            <input id="doTrails2" class="nav-logos fas" type="checkbox" onclick="toggleTrails()" />
            Signal Trails
          </label>

        </li>

        <li class="nav-item">
          <label class="nav-link nav-linkpage-scroll">
            <input id="showUnverifiedOnly2" class="nav-logos fas" type="checkbox" onclick="toggleShowUnverifiedOnly()" />
            Unverified Only
          </label>

        </li>

        <li class="nav-item">
          <label class="nav-link nav-linkpage-scroll" onclick="getTowersInView(MCC, MNC, true, netType)">
            <i class="nav-logos fas fa-redo"></i>
            Refresh Towers
          </label>

        </li>

        <li class="nav-item">
          <label class="nav-link nav-linkpage-scroll">
            Filter Tower Locator:
            <input type="text" id="locator_search" style="display: unset; font-size: 13.3333px; width: 83px; padding: 0px 3px; line-height: unset;" />
          </label>

        </li>
        `).insertAfter(supportLink);

            // I'm lazy: https://www.w3schools.com/howto/howto_js_trigger_button_enter.asp
            // Get the input field
            var input = document.getElementById("locator_search");

            // Execute a function when the user releases a key on the keyboard
            input.addEventListener("keyup", function (event) {
                // Number 13 is the "Enter" key on the keyboard
                if (event.keyCode === 13) {
                    // Cancel the default action, if needed
                    event.preventDefault();
                    try {
                        var input = document.getElementById("locator_search").value;
                        if (input.startsWith('!')) {
                            window.excludeFilterTowerMover = true;
                            input = input.substring(1);
                        } else {
                            window.excludeFilterTowerMover = false;
                        }

                        input = input.split(',').filter(function (x, i) { return x !== ''; });;
                        filterTowerMover = []
                        for (var a in input) {
                            filterTowerMover.push(parseInt(input[a]))
                        }

                        // Trigger the button element with a click
                        refreshTowers();
                    } catch {
                        // who cares
                    }
                }
            });


            window.togglingShowUnverifiedOnly = window.togglingTrails = true;
            $("#doTrails2").prop('checked', tilesEnabled);
            $("#showUnverifiedOnly2").prop('checked', showUnverifiedOnly);
            window.togglingShowUnverifiedOnly = window.togglingTrails = false;
        });

    function addGlobalStyle(css) {
        var head, style;
        head = document.getElementsByTagName('head')[0];
        if (!head) { return; }
        style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = css.replace(/;/g, ' !important;');
        head.appendChild(style);
    }
    addGlobalStyle(`
@media (min-width: 576px) {
    .modal-dialog {
        max-width:800px;
    }
`);

})();
