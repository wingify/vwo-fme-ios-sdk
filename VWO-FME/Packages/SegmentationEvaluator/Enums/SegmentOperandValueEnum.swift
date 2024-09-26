/**
 * Copyright 2024 Wingify Software Pvt. Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * Values for segment operands.
 *
 * This enum defines integer values associated with different types of segment operands. These
 * values can be used for comparison or evaluation purposes.
 */
enum SegmentOperandValueEnum: Int {
    case lowerValue = 1
    case startingEndingStarValue = 2
    case startingStarValue = 3
    case endingStarValue = 4
    case regexValue = 5
    case equalValue = 6
    case greaterThanValue = 7
    case greaterThanEqualToValue = 8
    case lessThanValue = 9
    case lessThanEqualToValue = 10
}
